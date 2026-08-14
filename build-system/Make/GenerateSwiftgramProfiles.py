import argparse
import os
import plistlib
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from BuildEnvironment import run_executable_with_output
from GenerateProfiles import setup_temp_keychain, cleanup_temp_keychain


def get_identity_from_keychain(keychain_name):
    for flags in (['-v', '-p', 'codesigning'], []):
        output = run_executable_with_output('security', arguments=['find-identity'] + flags + [keychain_name], check_result=True)
        if output is None:
            continue
        for line in output.splitlines():
            if '"' in line and ')' in line:
                return line.split('"')[1]
    return None


def rewrite_and_resign(source, destination, team_id, bundle_id, old_bundle_id, keychain_name, signing_identity):
    parsed_plist = run_executable_with_output('security', arguments=['cms', '-D', '-i', source], check_result=True)
    parsed_plist_file = tempfile.mktemp()
    with open(parsed_plist_file, 'w+') as file:
        file.write(parsed_plist)

    current_appid = run_executable_with_output('plutil', arguments=['-extract', 'Entitlements.application-identifier', 'raw', parsed_plist_file], check_result=True)
    if current_appid is None:
        print('No application-identifier in {}'.format(source))
        sys.exit(1)
    current_appid = current_appid.strip()

    prefix = team_id + '.' + old_bundle_id
    if not current_appid.startswith(prefix):
        print('Unexpected application-identifier {} in {}'.format(current_appid, source))
        sys.exit(1)

    suffix = current_appid[len(prefix):]
    new_appid = team_id + '.' + bundle_id + suffix
    print('Rewrote {} -> {}'.format(current_appid, new_appid))

    run_executable_with_output('plutil', arguments=['-replace', 'Entitlements.application-identifier', '-string', new_appid, parsed_plist_file], check_result=True)

    with open(parsed_plist_file, 'rb') as file:
        parsed_dict = plistlib.load(file)
    entitlements = parsed_dict.get('Entitlements')
    if entitlements is not None and 'com.apple.security.application-groups' in entitlements:
        entitlements['com.apple.security.application-groups'] = [
            g.replace('group.' + old_bundle_id, 'group.' + bundle_id) for g in entitlements['com.apple.security.application-groups']
        ]
        print('Rewrote app groups in {}: {}'.format(os.path.basename(source), ', '.join(entitlements['com.apple.security.application-groups'])))
        with open(parsed_plist_file, 'wb') as file:
            plistlib.dump(parsed_dict, file)

    run_executable_with_output('plutil', arguments=['-remove', 'DER-Encoded-Profile', parsed_plist_file], check_result=False)

    run_executable_with_output('security', arguments=[
        'cms', '-S', '-k', keychain_name, '-N', signing_identity, '-i', parsed_plist_file, '-o', destination
    ], check_result=True)

    os.unlink(parsed_plist_file)


def main():
    parser = argparse.ArgumentParser(prog='GenerateSwiftgramProfiles')
    parser.add_argument('--team-id', required=True)
    parser.add_argument('--bundle-id', required=True)
    parser.add_argument('--old-bundle-id', required=True)
    parser.add_argument('--input-dir', required=True)
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--certs-dir', required=True)
    args = parser.parse_args()

    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)

    p12_path = os.path.join(args.certs_dir, 'SelfSigned.p12')
    if not os.path.exists(p12_path):
        print('{} does not exist'.format(p12_path))
        sys.exit(1)

    keychain_name = setup_temp_keychain(p12_path, '')
    signing_identity = get_identity_from_keychain(keychain_name)
    if not signing_identity:
        print('Could not extract signing identity from keychain {}'.format(keychain_name))
        sys.exit(1)
    print('Using signing identity: {}'.format(signing_identity))

    try:
        for file_name in os.listdir(args.input_dir):
            if not file_name.endswith('.mobileprovision'):
                continue
            source = os.path.join(args.input_dir, file_name)
            destination = os.path.join(args.output_dir, file_name)
            print('Processing {}'.format(file_name))
            rewrite_and_resign(
                source=source,
                destination=destination,
                team_id=args.team_id,
                bundle_id=args.bundle_id,
                old_bundle_id=args.old_bundle_id,
                keychain_name=keychain_name,
                signing_identity=signing_identity
            )
    finally:
        cleanup_temp_keychain(keychain_name)
    print('Done. Generated profiles in {}'.format(args.output_dir))


if __name__ == '__main__':
    main()