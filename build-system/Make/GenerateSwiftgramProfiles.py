import argparse
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from BuildEnvironment import run_executable_with_output
from GenerateProfiles import setup_temp_keychain, cleanup_temp_keychain, get_signing_identity_from_p12, get_certificate_base64_from_p12


def rewrite_and_resign(source, destination, team_id, bundle_id, keychain_name, signing_identity):
    parsed_plist = run_executable_with_output('security', arguments=['cms', '-D', '-i', source], check_result=True)
    parsed_plist_file = tempfile.mktemp()
    with open(parsed_plist_file, 'w+') as file:
        file.write(parsed_plist)

    current_appid = run_executable_with_output('plutil', arguments=['-extract', 'Entitlements.application-identifier', 'raw', parsed_plist_file], check_result=True)
    if current_appid is None:
        print('No application-identifier in {}'.format(source))
        sys.exit(1)

    if not current_appid.startswith(team_id + '.'):
        print('Unexpected application-identifier {} in {}'.format(current_appid, source))
        sys.exit(1)

    base_name = current_appid[len(team_id + '.'):]
    dot_index = base_name.find('.')
    suffix = base_name[dot_index:] if dot_index != -1 else ''
    new_appid = team_id + '.' + bundle_id + suffix
    print('Rewrote {} -> {}'.format(current_appid, new_appid))

    run_executable_with_output('plutil', arguments=['-replace', 'Entitlements.application-identifier', '-string', new_appid, parsed_plist_file], check_result=True)
    run_executable_with_output('plutil', arguments=['-remove', 'DER-Encoded-Profile', parsed_plist_file], check_result=False)

    run_executable_with_output('security', arguments=[
        'cms', '-S', '-k', keychain_name, '-N', signing_identity, '-i', parsed_plist_file, '-o', destination
    ], check_result=True)

    os.unlink(parsed_plist_file)


def main():
    parser = argparse.ArgumentParser(prog='GenerateSwiftgramProfiles')
    parser.add_argument('--team-id', required=True)
    parser.add_argument('--bundle-id', required=True)
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

    signing_identity = get_signing_identity_from_p12(p12_path, '')
    if not signing_identity:
        print('Could not extract signing identity from {}'.format(p12_path))
        sys.exit(1)
    print('Using signing identity: {}'.format(signing_identity))

    keychain_name = setup_temp_keychain(p12_path, '')
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
                keychain_name=keychain_name,
                signing_identity=signing_identity
            )
    finally:
        cleanup_temp_keychain(keychain_name)
    print('Done. Generated profiles in {}'.format(args.output_dir))


if __name__ == '__main__':
    main()