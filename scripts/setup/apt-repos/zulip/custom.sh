#!/usr/bin/env bash
set -euo pipefail

if [[ ! -e /usr/share/doc/groonga-apt-source/copyright ]]; then
    pgroonga_apt_sign_key=$(readlink -f "$LIST_PATH/pgroonga-packages.groonga.org.asc")

    remove_pgroonga_apt_tmp_dir() {
        rm -rf "$pgroonga_apt_tmp_dir"
    }
    pgroonga_apt_tmp_dir=$(mktemp --directory)
    trap remove_pgroonga_apt_tmp_dir EXIT

    {
        cd "$pgroonga_apt_tmp_dir" || exit 1
        tmp_gpg_home=.gnupg
        gpg --homedir="$tmp_gpg_home" --import "$pgroonga_apt_sign_key"
        # Find fingerprint of the first key.
        pgroonga_apt_sign_key_fingerprint=$(
            gpg --homedir="$tmp_gpg_home" --with-colons --list-keys \
                | grep '^fpr:' \
                | cut --delimiter=: --fields=10 \
                | head --lines=1
        )
        os_info="$(. /etc/os-release && printf '%s\n' "$ID" "$VERSION_CODENAME")"
        {
            read -r distribution
            read -r release
        } <<<"$os_info"

        if [ "$distribution" = ubuntu ] && [ "$release" = noble ]; then
            # PGroonga binaries are not yet provided for Ubuntu 24.04.
            exit
        fi
        groonga_apt_source_deb="groonga-apt-source-latest-$release.deb"
        groonga_apt_source_deb_sign="$groonga_apt_source_deb.asc.$pgroonga_apt_sign_key_fingerprint"
        #curl --proxy "http://proxy.infra.cloud.e2.rie.gouv.fr:1080" -fLO --retry 3 "https://github.com/gfournel/zulip/blob/3a772d79a021a06384dabf4918f8c63d0c0c7392/$groonga_apt_source_deb"
        #curl --proxy "http://proxy.infra.cloud.e2.rie.gouv.fr:1080" -fLO --retry 3 "https://github.com/gfournel/zulip/blob/3a772d79a021a06384dabf4918f8c63d0c0c7392/$groonga_apt_source_deb_sign"
        gpg \
            --homedir="$tmp_gpg_home" \
            --verify \
            "$groonga_apt_source_deb_sign" \
            "$groonga_apt_source_deb"
        # To suppress the following warning by "apt-get install":
        #   N: Download is performed unsandboxed as root as file
        #   '.../groonga-apt-source-latest-$release.deb' couldn't be
        #   accessed by user '_apt'. - pkgAcquire::Run (13: Permission denied)
        chown _apt .

        apt-get -y install "./$groonga_apt_source_deb"
    }
    touch "$STAMP_FILE"
fi
