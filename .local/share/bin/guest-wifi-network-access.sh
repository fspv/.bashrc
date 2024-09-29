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
echo -e "Now run\n\$ firefox http://localhost:5800"
/init >/dev/null 2>&1
EOF

sudo docker run \
    --rm \
    --cap-add=NET_ADMIN \
    --network host \
    -p 127.0.0.1:5800:5800 \
    -e 'FF_PREF_HOMEPAGE_OVERRIDE_DISABLE=browser.startup.homepage_override.mstone=\"ignore\"' \
    -e 'FF_PREF_HOMEPAGE=browser.startup.homepage=\"connectivitycheck.gstatic.com\"' \
    -v "${TMP_SCRIPT}":/dhcp-and-init.sh \
    --name firefox \
    -it jlesage/firefox \
    sh -e /dhcp-and-init.sh || true

rm "${TMP_SCRIPT}"
