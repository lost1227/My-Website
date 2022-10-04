#!/usr/bin/python3
import argparse
import subprocess
import re

DEFAULT_CLIENT_IP = "10.8.0.201"
SERVER_VPN_INTERFACE = "tun0"

# List rules: sudo iptables -t nat -L --line-numbers
# Delete rule: sudo iptables -t nat -D (PREROUTING|POSTROUTING) 1

server_ip_re = re.compile(r'(?<=inet\s)\d+(?:\.\d+){3}')

def do_forward(args):
    completion = subprocess.run(['ip', '-4', 'addr', 'show', 'dev', SERVER_VPN_INTERFACE], text=True, stdout=subprocess.PIPE)
    completion.check_returncode()
    match = server_ip_re.search(completion.stdout)
    if not match:
        raise ValueError('Unexpected output from `ip addr`')
    server_ip = match.group(0)

    if args.protocol == 'both':
        protocols = ['tcp', 'udp']
    else:
        protocols = [args.protocol]

    for protocol in protocols:
        dnat = f"sudo iptables -t nat -A PREROUTING -p {protocol} --dport {args.port} -j DNAT --to-dest {args.client_ip}:{args.port}"
        snat = f"sudo iptables -t nat -A POSTROUTING -d {args.client_ip} -p {protocol} --dport {args.port} -j SNAT --to-source {server_ip}"

        print(dnat)
        subprocess.run(dnat, shell=True).check_returncode()

        print(snat)
        subprocess.run(snat, shell=True).check_returncode()

def do_list(args):
    subprocess.run(['sudo', 'iptables', '-t', 'nat', '-L', 'PREROUTING', '--line-numbers'])
    subprocess.run(['sudo', 'iptables', '-t', 'nat', '-L', 'POSTROUTING', '--line-numbers'])

def do_delete(args):
    subprocess.run(['sudo', 'iptables', '-t', 'nat', '-D', args.chain, str(args.rule_idx)])
    do_list(args)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Manage port forwarding")
    subparsers = parser.add_subparsers(required=True)

    parser_forward = subparsers.add_parser('forward', help='Forward a port')
    parser_forward.add_argument('port', type=int, help='the port to forward')
    parser_forward.add_argument('protocol', choices=['tcp', 'udp', 'both'], default='both', nargs='?', help='the protocol to forward')
    parser_forward.add_argument('--client-ip', default=DEFAULT_CLIENT_IP, help='the client ip address to which traffic will be forwarded')
    parser_forward.set_defaults(func=do_forward)

    parser_list = subparsers.add_parser('list', help='List forwarded ports')
    parser_list.set_defaults(func=do_list)

    parser_delete = subparsers.add_parser('delete', help='Unforward a port')
    parser_delete.add_argument('chain', choices=['PREROUTING', 'POSTROUTING'], help='The chain containing the rule to remove')
    parser_delete.add_argument('rule_idx', type=int, help='The index in the specified chain of the rule to remove')
    parser_delete.set_defaults(func=do_delete)

    args = parser.parse_args()


    args.func(args)



