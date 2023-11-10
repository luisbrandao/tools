#!/usr/bin/python3.8
import time
import sys
import dns.resolver
from requests import get
import boto3
import logging
import click

logger = logging.getLogger(__name__)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

get_change_id = lambda response: response['ChangeInfo']['Id'].split('/')[-1]
get_change_status = lambda response: response['ChangeInfo']['Status']

def resolve_name_ip(domain):
    try:
        resolver = dns.resolver.Resolver()
        resolver.nameservers = ["8.8.8.8"]  # Set the custom DNS resolver address
        answers = resolver.resolve(domain, 'A')
        ip_address = answers[0].address
        return ip_address
    except (dns.resolver.NXDOMAIN, dns.resolver.Timeout):
        return "Unable to resolve the domain."

def change_route53_a_record(hosted_zone_id, domain_name, new_ip):
    # Initialize the Route 53 client
    route53_client = boto3.client('route53')

    # List the existing records for the specified domain name
    response = route53_client.list_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        StartRecordName=domain_name,
        StartRecordType='A'
    )

    # Extract the existing record information
    record_sets = response['ResourceRecordSets']

    if not record_sets:
        print(f"No 'A' record found for {domain_name} in the specified hosted zone.")
        return

    # Create a change batch to update the record
    change_batch = {
        'Changes': [
            {
                'Action': 'UPSERT',
                'ResourceRecordSet': {
                    'Name': domain_name,
                    'Type': 'A',
                    'TTL': 300,  # Set the TTL (time to live) as needed
                    'ResourceRecords': [{'Value': new_ip}]
                }
            }
        ]
    }

    # Update the Route 53 record
    response = route53_client.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch=change_batch
    )

    print(f"Updated 'A' record for {domain_name} to {new_ip}.")
    return response

@click.command()
@click.option('--hosted-zone', '-z', 'HOSTED_ZONE', type=str, required=True, help='Select AWS hosted zone id')
@click.option('--domain-name', '-n', 'DOMAIN_NAME', type=str, required=True, help='Select the domain to be updated')
def main(HOSTED_ZONE, DOMAIN_NAME):
    # Get your ip using a public service
    try:
        #current_ip = get('https://ident.me').text
        #current_ip = get('https://ipv4.lafibre.info/ip.php').text
        current_ip = get('https://checkip.amazonaws.com').text
        current_ip = current_ip.replace("\n", "")
    except:
        logger.error('Internet is down')
        sys.exit(1)

    # Avoid to hit the Route53 API if is not necessary.
    # so compare first to a DNS server if the IP changed
    resolved_ip = resolve_name_ip(DOMAIN_NAME)
    if resolved_ip == current_ip:
        logger.debug('DNS response (%s) and public IP (%s) are the same, nothing to do' % (resolved_ip, current_ip))
        return

    hosted_zone_id = 'YOUR_HOSTED_ZONE_ID'
    domain_name = 'example.com'
    new_ip = 'NEW_IP_ADDRESS'

    change_route53_a_record(HOSTED_ZONE, DOMAIN_NAME, current_ip)

if __name__ == '__main__':
    main()
