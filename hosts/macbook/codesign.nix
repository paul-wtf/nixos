{ config, lib, ... }:
let
  # TCC ties the Accessibility grant to the binary's path and designated
  # requirement; a store path and an ad-hoc cdhash both change on every rebuild.
  # These agents therefore run a copy at a fixed path, signed with a local
  # certificate. `sudo yabai --load-sa` stays on the store binary because the
  # nix-darwin sudoers rule pins its sha256.
  binaries = {
    yabai = "${config.services.yabai.package}/bin/yabai";
    skhd = "${config.services.skhd.package}/bin/skhd";
  };

  signDir = "/var/db/nix-codesign";
  keychain = "${signDir}/codesign.keychain-db";
  binDir = "/usr/local/libexec/nix-codesign";
  uid = "$(id -u ${config.system.primaryUser})";

  signOne = name: src: ''
    if [ "$(/bin/cat "${binDir}/${name}.source" 2>/dev/null)" != "${src} $identity" ] \
        || [ ! -x "${binDir}/${name}" ]; then
      echo "signing ${name} for a stable Accessibility grant..."
      /bin/cp -f "${src}" "${binDir}/.${name}.tmp"
      /bin/chmod 755 "${binDir}/.${name}.tmp"
      /usr/bin/codesign --force --keychain "${keychain}" -s "$identity" -i "${name}" "${binDir}/.${name}.tmp"
      /bin/mv -f "${binDir}/.${name}.tmp" "${binDir}/${name}"
      echo "${src} $identity" > "${binDir}/${name}.source"
      codesignChanged="$codesignChanged ${name}"
    fi
  '';
in
{
  system.activationScripts.extraActivation.text = ''
    if [ ! -e "${keychain}" ]; then
      echo "creating local code signing identity in ${signDir}..."
      /bin/mkdir -p "${signDir}"
      /bin/chmod 700 "${signDir}"
      tmp=$(/usr/bin/mktemp -d)
      /usr/bin/openssl rand -hex 32 > "${signDir}/password"
      /bin/chmod 600 "${signDir}/password"
      /bin/cat > "$tmp/cert.cnf" <<'EOF'
    [req]
    distinguished_name=dn
    x509_extensions=ext
    prompt=no
    [dn]
    CN=nix-codesign
    [ext]
    basicConstraints=critical,CA:false
    keyUsage=critical,digitalSignature
    extendedKeyUsage=critical,codeSigning
    EOF
      /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
        -config "$tmp/cert.cnf" -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
      /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -out "$tmp/id.p12" -passout pass:import
      /usr/bin/security create-keychain -p "$(/bin/cat "${signDir}/password")" "${keychain}"
      /usr/bin/security set-keychain-settings "${keychain}"
      /usr/bin/security import "$tmp/id.p12" -k "${keychain}" -P import -T /usr/bin/codesign
      /usr/bin/security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
        -k "$(/bin/cat "${signDir}/password")" "${keychain}" > /dev/null
      /usr/bin/openssl x509 -in "$tmp/cert.pem" -noout -fingerprint -sha1 \
        | /usr/bin/sed 's/.*=//; s/://g' > "${signDir}/identity"
      /bin/rm -rf "$tmp"
    fi

    /usr/bin/security unlock-keychain -p "$(/bin/cat "${signDir}/password")" "${keychain}"
    identity=$(/bin/cat "${signDir}/identity")
    /bin/mkdir -p "${binDir}"
    codesignChanged=""
    ${lib.concatStrings (lib.mapAttrsToList signOne binaries)}
  '';

  launchd.user.agents = lib.mapAttrs (name: _: {
    serviceConfig.Program = "${binDir}/${name}";
  }) binaries;

  system.activationScripts.postActivation.text = ''
    for agent in $codesignChanged; do
      launchctl kickstart -k "gui/${uid}/org.nixos.$agent" || true
    done
  '';
}
