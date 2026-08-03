//! Generation-rotated backups of a colocated jj repository's state.
//!
//! A generation holds the repository's metadata — git objects and refs, jj's
//! operation log and working-copy state — but not the checked-out files, which
//! `restore` materialises from the working-copy commit it recorded.

pub mod backup;
pub mod manifest;
pub mod pointers;
pub mod restore;
pub mod verify;
