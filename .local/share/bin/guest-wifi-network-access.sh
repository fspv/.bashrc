#!/bin/sh

IFACE=$1
TMP_SCRIPT=$(mktemp)

chmod +rx "${TMP_SCRIPT}"

cat << EOF > "${TMP_SCRIPT}"
#!/bin/sh -e

mkdir -p /etc/udhcpc
echo RESOLV_CONF=/etc/resolv.conf.new >> /etc/udhcpc/udhcpc.conf
udhcpc -i "${IFACE}" || true
cat /etc/resolv.conf.new > /etc/resolv.conf

# Wait a moment for the container to initialize
sleep 2

# Find Firefox profile directory and create user.js
PROFILE_DIR=\$(find /config -name "*.default*" -type d 2>/dev/null | head -1)
if [ -z "\$PROFILE_DIR" ]; then
    # If no profile found, create one in the expected location
    mkdir -p /config/profile
    PROFILE_DIR="/config/profile"
fi

# Create user.js in the profile directory
cat > "\${PROFILE_DIR}/user.js" << 'EOL'
user_pref("browser.startup.homepage", "https://connectivitycheck.gstatic.com");
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_override_url", "");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.aboutHomeSnippets.updateUrl", "");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtab.url", "https://connectivitycheck.gstatic.com");
EOL

# Also create a prefs.js file to ensure settings are applied
cat > "\${PROFILE_DIR}/prefs.js" << 'EOL'
user_pref("browser.startup.homepage", "https://connectivitycheck.gstatic.com");
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_override_url", "");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.aboutHomeSnippets.updateUrl", "");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtab.url", "https://connectivitycheck.gstatic.com");
EOL

echo -e "Firefox profile configured at: \${PROFILE_DIR}"
echo -e "Now run\n\$ firefox http://localhost:5800"

/init >/dev/null 2>&1
EOF

sudo docker run \
    --rm \
    --cap-add=NET_ADMIN \
    --network host \
    -v "${TMP_SCRIPT}":/dhcp-and-init.sh \
    -v /your/local/firefox/config/path:/config:rw \
    --name firefox \
    -it jlesage/firefox \
    sh -e /dhcp-and-init.sh || true

rm "${TMP_SCRIPT}"