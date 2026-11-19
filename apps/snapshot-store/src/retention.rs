//! Which generations a store keeps, as a pure function of their timestamps.

use std::collections::HashSet;

use jiff::{SignedDuration, Timestamp};

use crate::GenerationId;

/// The span of ages a [`Tier`] applies to.
#[derive(Debug, Clone, Copy)]
pub enum Age {
    UpTo(SignedDuration),
    Unbounded,
}

/// How densely generations are kept within a [`Tier`].
#[derive(Debug, Clone, Copy)]
pub enum Density {
    All,
    OnePer(SignedDuration),
}

#[derive(Debug, Clone, Copy)]
pub struct Tier {
    pub covering: Age,
    pub keeping: Density,
}

/// Tiers in increasing order of age. A generation belongs to the first tier
/// covering its age, and survives only as the newest one in its slot.
#[derive(Debug, Clone)]
pub struct Retention {
    tiers: Vec<Tier>,
}

impl Default for Retention {
    fn default() -> Self {
        Self {
            tiers: vec![
                Tier {
                    covering: Age::UpTo(SignedDuration::from_hours(1)),
                    keeping: Density::All,
                },
                Tier {
                    covering: Age::UpTo(SignedDuration::from_hours(24)),
                    keeping: Density::OnePer(SignedDuration::from_hours(1)),
                },
                Tier {
                    covering: Age::UpTo(SignedDuration::from_hours(24 * 7)),
                    keeping: Density::OnePer(SignedDuration::from_hours(24)),
                },
                Tier {
                    covering: Age::Unbounded,
                    keeping: Density::OnePer(SignedDuration::from_hours(24 * 30)),
                },
            ],
        }
    }
}

impl Retention {
    #[must_use]
    pub const fn new(tiers: Vec<Tier>) -> Self {
        Self { tiers }
    }

    /// The generations no tier keeps, newest-first within each slot.
    #[must_use]
    pub fn expired(&self, generations: &[GenerationId], now: Timestamp) -> Vec<GenerationId> {
        let mut newest_first = generations.to_vec();
        newest_first.sort_unstable_by(|left, right| right.cmp(left));

        let mut claimed: HashSet<(usize, i64)> = HashSet::new();
        let mut expired = Vec::new();
        for generation in newest_first {
            match self.tier_for(now - generation.moment()) {
                Some((index, tier)) => {
                    if !claimed.insert((index, slot(&tier, generation))) {
                        expired.push(generation);
                    }
                }
                None => expired.push(generation),
            }
        }
        expired
    }

    fn tier_for(&self, age: SignedDuration) -> Option<(usize, Tier)> {
        self.tiers
            .iter()
            .enumerate()
            .find(|(_, tier)| match tier.covering {
                Age::UpTo(limit) => age <= limit,
                Age::Unbounded => true,
            })
            .map(|(index, tier)| (index, *tier))
    }
}

/// Slots are anchored to absolute time rather than to age, so a generation stays
/// in the same slot from one run to the next.
fn slot(tier: &Tier, generation: GenerationId) -> i64 {
    let seconds = generation.moment().as_second();
    match tier.keeping {
        Density::All => seconds,
        Density::OnePer(window) => seconds.div_euclid(window.as_secs().max(1)),
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::panic)]
mod tests {
    use jiff::{SignedDuration, Timestamp};

    use super::{Age, Density, Retention, Tier};
    use crate::GenerationId;

    fn now() -> Timestamp {
        Timestamp::from_second(1_800_000_000).unwrap()
    }

    fn generations(ages: &[SignedDuration]) -> Vec<GenerationId> {
        ages.iter()
            .map(|age| GenerationId::at(now() - *age))
            .collect()
    }

    #[test]
    fn keeps_every_generation_inside_the_first_tier() {
        let all = generations(&[
            SignedDuration::from_secs(30),
            SignedDuration::from_secs(60),
            SignedDuration::from_mins(59),
        ]);
        assert_eq!(
            Retention::default().expired(&all, now()),
            Vec::<GenerationId>::new()
        );
    }

    #[test]
    fn thins_the_day_to_the_newest_generation_of_each_hour() {
        let all = generations(&[
            SignedDuration::from_hours(2) + SignedDuration::from_mins(10),
            SignedDuration::from_hours(2) + SignedDuration::from_mins(30),
            SignedDuration::from_hours(2) + SignedDuration::from_mins(50),
            SignedDuration::from_hours(5),
        ]);
        assert_eq!(
            Retention::default().expired(&all, now()),
            vec![all[1], all[2]]
        );
    }

    #[test]
    fn thins_the_week_to_one_generation_per_day() {
        let all = generations(&[
            SignedDuration::from_hours(24 * 2),
            SignedDuration::from_hours(24 * 2) + SignedDuration::from_hours(6),
            SignedDuration::from_hours(24 * 3),
        ]);
        assert_eq!(Retention::default().expired(&all, now()), vec![all[1]]);
    }

    #[test]
    fn keeps_one_generation_per_month_indefinitely() {
        let all = generations(&[
            SignedDuration::from_hours(24 * 40),
            SignedDuration::from_hours(24 * 40) + SignedDuration::from_hours(1),
            SignedDuration::from_hours(24 * 200),
        ]);
        assert_eq!(Retention::default().expired(&all, now()), vec![all[1]]);
    }

    #[test]
    fn a_bounded_policy_expires_everything_beyond_its_last_tier() {
        let policy = Retention::new(vec![Tier {
            covering: Age::UpTo(SignedDuration::from_hours(1)),
            keeping: Density::All,
        }]);
        let all = generations(&[SignedDuration::from_mins(30), SignedDuration::from_hours(3)]);
        assert_eq!(policy.expired(&all, now()), vec![all[1]]);
    }

    #[test]
    fn slots_do_not_shift_as_time_passes() {
        let all = generations(&[
            SignedDuration::from_hours(2),
            SignedDuration::from_hours(2) + SignedDuration::from_mins(30),
        ]);
        let policy = Retention::default();
        let expired = policy.expired(&all, now());
        assert_eq!(
            expired,
            policy.expired(&all, now() + SignedDuration::from_mins(5))
        );
    }
}
