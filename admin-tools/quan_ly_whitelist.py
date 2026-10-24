"""Create reviewed, expiring TEST IP policy locally. Never uploads or edits a server."""
import argparse
from datetime import datetime, timezone
import hashlib
import ipaddress
import json
from pathlib import Path
import re
import time


def network_code(ip):
    address = ipaddress.IPv4Address(ip)
    if not address.is_global or str(address) != ip:
        raise ValueError('Can IP public IPv4 chuan, khong dung IP LAN/proxy/CIDR')
    return hashlib.sha256(('WESTSIDE_TEST_EAC_COMPAT_V1|' + ip).encode('ascii')).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--ip', help='Public IPv4 cua tiem net; chi hash duoc ghi vao policy')
    action.add_argument('--code', help='Ma mang SHA-256 hien tren hop ho tro')
    action.add_argument('--remove-code', help='Thu hoi ma mang trong policy')
    action.add_argument('--disable-all', action='store_true')
    parser.add_argument('--hours', type=int, default=4, choices=range(1, 25))
    parser.add_argument('--output', type=Path, default=Path(__file__).parent / 'policy/eac-cafe-1000076.json')
    args = parser.parse_args()
    policy = {'schema': 1, 'client': 'westside-test', 'version': 1000076, 'enabled': False, 'networks': []}
    if args.output.exists():
        policy = json.loads(args.output.read_text(encoding='utf-8'))
        assert set(policy) == {'schema', 'client', 'version', 'enabled', 'networks'}
        assert policy['schema'] == 1 and policy['client'] == 'westside-test' and policy['version'] == 1000076
        assert isinstance(policy['enabled'], bool) and isinstance(policy['networks'], list)
    now = int(time.time())
    seen = set()
    for item in policy['networks']:
        assert set(item) == {'sha256', 'notBefore', 'notAfter'} and re.fullmatch('[0-9a-f]{64}', item['sha256'])
        assert item['sha256'] not in seen and isinstance(item['notBefore'], int) and isinstance(item['notAfter'], int)
        assert 0 <= item['notBefore'] < item['notAfter'] <= item['notBefore'] + 86400
        seen.add(item['sha256'])
    if args.disable_all:
        policy['enabled'] = False
        policy['networks'] = []
    else:
        code = network_code(args.ip) if args.ip else (args.code or args.remove_code)
        assert re.fullmatch('[0-9a-f]{64}', code), 'Ma mang khong hop le'
        policy['networks'] = [item for item in policy['networks'] if item['sha256'] != code and item['notAfter'] > now]
        if not args.remove_code:
            policy['networks'].append({'sha256': code, 'notBefore': now, 'notAfter': now + args.hours * 3600})
        policy['enabled'] = bool(policy['networks'])
    assert len(policy['networks']) <= 256
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists():
        backup = args.output.with_name(args.output.name + '.before-' + str(time.time_ns()))
        backup.write_bytes(args.output.read_bytes())
    temp = args.output.with_name(args.output.name + '.tmp-' + str(time.time_ns()))
    temp.write_text(json.dumps(policy, indent=2) + '\n', encoding='utf-8')
    temp.replace(args.output)
    print('DA GHI LOCAL:', args.output)
    print('CHUA upload GitHub. Review roi chep dung policy/eac-cafe-1000076.json vao UPDATE_LAUNCHER_TEST/main.')
    print('So mang:', len(policy['networks']), '| enabled:', policy['enabled'])
    for item in policy['networks']:
        print('Ma:', item['sha256'], '| het han UTC:', datetime.fromtimestamp(item['notAfter'], timezone.utc).isoformat())
    print('IP chung NAT/tiem net ap dung moi may cung IP. Khong phai xac thuc EAC tu server.')


if __name__ == '__main__':
    main()
