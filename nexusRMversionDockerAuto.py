import requests
import click
import json
from typing import Optional
from operator import itemgetter

@click.command()
@click.option('--user', '-u', 'USER', type=str, required=False, help='Nexus user', default='')
@click.option('--pass', '-p', 'PASS', type=str, required=False, help='Nexus password', default=')
@click.option('--url', '-l', 'URL', type=str, required=False, help='Nexus base url (https://nexus.example.com)', default='https://nexus.example.com')
@click.option('--repo', '-r', 'REPO', type=str, required=False, help='Nexus working repo (local-registry)', default='local-registry')
@click.option('--name', '-n', 'NAME', type=str, required=True, help='Nome do componente a ser apagado (Container-name)')
@click.option('--prefix', '-p', 'PREFIX', type=str, required=True, help='Prefixo do componente a ser apagado (blue-*)')

def main(USER,PASS,URL,REPO,NAME,PREFIX):
    session = requests.Session()
    session.auth = (USER, PASS)

    # Primeira chamada
    params={"repository_name": REPO, "name":NAME, "version":PREFIX }
    search_url = URL + "/service/rest/v1/search"
    r = requests.get(search_url, params)
    data = r.json()
    continuation_token=data['continuationToken']
    listao = []
    for item in data['items']:
        dict = {"version_num": int(item["version"].split("-")[1]),
                "version_name": item["version"],
                "name": item["name"],
                "sha256": item["assets"][0]["checksum"]["sha256"]}
        listao.append(dict)

    # While there is a continuationToken
    while (continuation_token):
        continuation_token=data['continuationToken']
        params={"repository_name":REPO,
                "name":NAME,
                "version":PREFIX,
                "continuationToken":continuation_token}
        r = requests.get(search_url, params)
        data = r.json()
        for item in data['items']:
            dict = {"version_num": int(item["version"].split("-")[1]),
                    "version_name": item["version"],
                    "name": item["name"],
                    "sha256": item["assets"][0]["checksum"]["sha256"]}
            listao.append(dict)

    listao = sorted(listao, key=itemgetter('version_num'))
    del listao[-5:]

    for item in listao:
        print ("{}{}".format(item['name'],item['version_name']))

    if (query_yes_no("Apagar esses itens?")):
        print ("\n")
        for item in listao:
            delete_item(session, URL, REPO, item)

def delete_item(session: requests.sessions.Session, nexus_url: str, nexus_repo: str, item: dict):
    url=f"{nexus_url}/repository/{nexus_repo}/v2/{item['name']}/manifests/sha256:{item['sha256']}"
    r = session.delete(url)
    print ("{} - {}{} -- {}".format(r.status_code, item['name'],item['version_name'],url))

def query_yes_no(question, default="no"):
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        sys.stdout.write(question + prompt)
        choice = input().lower()
        if default is not None and choice == "":
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' " "(or 'y' or 'n').\n")

if __name__ == "__main__":
    main()
