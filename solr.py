#!/usr/bin/env python

# ****************************************
# @author Anderson Contreira <anderson.contreira@rentcars.com>
# ****************************************

# imports
import sys, re, time
import click, pycurl, json
import xml.etree.ElementTree as ET
from random import randint

# compatibilidade de versoes do python
try:
    # python2
    from StringIO import StringIO
    from StringIO import BytesIO
except ImportError:
    # python3
    from io import StringIO
    from io import BytesIO

class SolrStatus:
    """
    Class SolrStatus
    Lista os cores, verifica o numero de itens por core e realiza o import dos mesmos conforme as flags informadas
    """

    def __init__(self, url, core, import_core, debug):
        """
        Constructor
        :param url:
        :param core:
        :param import_core:
        :param debug:
        """
        self.debug = debug
        self.core = core
        self.import_core = import_core
        self.import_core_iterator = 0
        self.sleep_time = 0.8

        self.url = self.treat_url(url, core)

        pass

    def call_core_url(self, core):
        """

        Captura o numero de itens de um core especifico ou de todos se for passado o nome do core como "all"

        :param core:
        :return:
        """
        results = dict()

        if core == "all":

            print("Calling all cores...")

            cores = self.call_core_list()
            for core in cores:
                res = self.call_core_url(core)
                results[core] = res[core]

        else:
            try:
                url = self.url + "/solr/" + core + "/select?fl=id&indent=on&q=*:*&wt=json"

                print("URL: %s" % url)

                str_body = self.curl_exec(url)

                num_found = 0

                try:
                     # tenta com json
                     content = json.loads(str_body)

                     if content['response'] is not None:
                         if content['response']['numFound']:
                            num_found = content['response']['numFound']
                            results[core] = num_found
                #
                except Exception:

                    # tenta com xml
                    root = ET.fromstring(str_body)
                    if root.iter('response') is not None:
                        num_found_node = root.iter('response').iter('numFound')

                        if num_found_node is not None:
                            num_found = str(num_found_node.text)
                            results[core] = num_found

            except Exception as detail:
                error(detail)

        return results

    def call_core_list(self):
        """
        Lista de todos os cores do SOLR

        :return:
        """
        statuses = list()

        #acrecenta a parte do cores
        url = self.url + "/solr/admin/cores?action=STATUS"

        print("URL: %s" % url)

        try:
            str_body = self.curl_exec(url)

            try:

                # tenta com json
                content = json.loads(str_body)
                if content['status'] is not None:
                    for key, value in dict(content['status']).items():
                        if value['name']:
                            statuses.append(value['name'])

            except Exception:

                # tenta com xml
                root = ET.fromstring(str_body)
                if root.iter('response') is not None:

                    # l ocaliza o nome dos cores
                    names = root.findall("./lst[@name='status']//str[@name='name']")
                    for status in names:
                        core_name = str(status.text)
                        statuses.append(core_name)


        except Exception as detail:
            error(detail)

        return statuses

    def curl_exec(self, url):
        """
        Executa uma chamada cURL

        :param url:
        :return:
        """
        str_body = ""

        # buffer de retorno
        buffer = BytesIO()

        # inicializa o curl
        curl = pycurl.Curl()
        curl.setopt(curl.URL, url)
        curl.setopt(curl.VERBOSE, self.debug)
        curl.setopt(curl.WRITEDATA, buffer)

        try:

            curl.perform()
            body = buffer.getvalue()

            try:

                str_body = body.decode('utf-8')

            except Exception as detail:
                error(detail)

        except Exception as detail:
            error(detail)

        # fecha a chamada curl
        curl.close()

        return str_body

    def treat_url(self, url, core):

        """
        Faz o tratamento da url informada
        :param url:
        :param core:
        :return:
        """
        pattern = re.compile("http[s]?://")
        match = pattern.search(url)

        # se nao tiver o http entao acrescenta
        if match is None:
            url = "http://" + url

        # verifica se nao tem dados da url
        pattern = re.compile("/solr/admin")
        match = pattern.search(url)

        if match is not None:
            url = url.replace("/solr/admin/cores?action=STATUS","")

        if core is not None:
            # verifica se nao tem dados da url
            pattern = re.compile("/solr/" + core + "/select")
            match = pattern.search(url)

            if match is not None:
                url = url.replace("/solr/regras/select?fl=id&indent=on&q=*:*&wt=json", "")

        return url

    def execute(self):
        """
        Executa uma funcao com base nos parametros

        :return:
        """
        if self.url is not None and self.core is not None:
            # data import
            if self.import_core is not None and self.import_core is True:
                # executa o import
                self.import_core_execution()
            # list rows count
            else:
                # lista o total de rows
                self.row_count_execution()

        else:

           self.list_cores_execution();

    def import_core_execution(self):
        """
        Executa o import do core do SOLR e imprime os dados
        :return:
        """
        if self.core == "all":
            print("Importing all cores...")

            try:
                cores = self.call_core_list()
                # nao usar threads porque pode sobrecarregar o SOLR
                for core in cores:
                    print("Executing Data-Import from SOLR '%s' core..." % core)
                    print("")

                    data_import_info = self.data_import(core, True)

                    self.print_info(data_import_info)

                    if len(data_import_info.items()) > 0:
                        self.data_import_callback(data_import_info, True)

                    print("")


            except Exception as detail:
                error(detail)
        else:
            print("Executing Data-Import from SOLR '%s' core..." % self.core)
            print("")

            data_import_info = self.data_import(self.core, True)

            self.print_info(data_import_info)

            if len(data_import_info.items()) > 0:
                self.data_import_callback(data_import_info, True)

            print("")
        print("Finished '%s' core Data-Import" % self.core)

        pass

    def row_count_execution(self):
        """
        Executa a contagem de rows do core do SOLR e imprime os dados
        :return:
        """
        print("Getting info from SOLR '%s' core..." % self.core)

        results = self.call_core_url(self.core)

        print("")
        if len(results) > 0:
            print("SOLR cores result:")
            for key, value in dict(results).items():
                # print(key,value)
                print("%s: %d" % (key, value))
        else:
            print("Unable to show '%s' core info." % self.core)

        pass

    def list_cores_execution(self):
        """
        Executa a consulta de cores no SOLR e imprime os dados
        :return:
        """
        print("Listing SOLR cores...")

        statuses = self.call_core_list()

        print("")
        if len(statuses) > 0:
            statuses.sort()
            print("SOLR cores:")
            for core in statuses:
                print(core)
        else:
            print("Unable to list SOLR cores.")

    def data_import(self, core, do_import):
        """
        Executa a chamada de importacao

        :param core:
        :param do_import:
        :return:
        """
        self.import_core_iterator += 1

        data_import_info = dict()

        try:
            if do_import:
                # import url
                url = self.url + "/solr/" + core + "/dataimport?command=full-import&clean=true&commit=true&optimize=true&wt=json&indent=false&verbose=false&debug=false"

                print("URL: %s" % url)
            else:

                # status
                url = self.url + "/solr/" + core + "/dataimport?command=status&indent=true&wt=json&_=" + str(randint(0, 1000000))


            str_body = self.curl_exec(url)

            try:
                # tenta com o json
                content = json.loads(str_body)
                if content['statusMessages'] is not None:

                    status_message = content['statusMessages']
                    data_import_info['core'] = core
                    data_import_info['status'] = content['status']

                    if len(status_message) > 0:
                        data_import_info['totalItems'] = status_message['Total Rows Fetched']
                        data_import_info['totalProcessedItems'] = status_message['Total Documents Processed']
                    else:
                        data_import_info['totalItems'] = 0
                        data_import_info['totalProcessedItems'] = 0

                    data_import_info['import_core_iterator'] = self.import_core_iterator


            except Exception as detail:
                error(detail)
                # tenta com o XML
                #root = ET.fromstring(str_body)

        except Exception as detail:
            error(detail)

        return data_import_info

    def print_info(self, data_import_info):
        """
        Imprime as informacoes de execucao do data-import do core do SOLR, mantem na mesma linha a resposta ate que seja
        concluida essa tarefa

        :param data_import_info:
        :return:
        """
        info = ""
        if len(data_import_info) > 0:
            iteration = data_import_info['import_core_iterator']

            info += "Executing step: " + str(iteration) + " => "
            info += "[SOLR '%s' core import info] " % data_import_info['core']
            info += "status => %s " % data_import_info['status']
            info += ", processed => %s rows" % data_import_info['totalProcessedItems']
            info += "     "

        else:
            info += "Unable to import '%s' core. " % self.core

        print_no_newline(info)
        pass

    def data_import_callback(self, data_import_info, first_call):
        """
        Callback para a chamada de data import, realiza a consulta do status da importacao e finaliza quando o status do core
        muda de 'busy' para 'idle'

        :param data_import_info:
        :param first_call:
        :return:
        """
        self.print_info(data_import_info)

        if first_call:
            data_import_info = self.data_import(data_import_info['core'], False)
            self.data_import_callback(data_import_info, False)

        else:
            status = data_import_info['status']

            if status == "busy":
                # collect the status
                data_import_info = self.data_import(data_import_info['core'], False)
                time.sleep(self.sleep_time)
                self.data_import_callback(data_import_info, False)
            else:
                print("\nFinished...")

        pass

def print_no_newline(string):
    """
    Mantem os dados que serao imprimidos na mesma linha

    :param string:
    :return:
    """
    sys.stdout.write("\r{0}".format(string))
    sys.stdout.flush()

def error(exception):
    """

    Imprime a mensagem de erro e encerra o programa

    :param exception:
    :return:
    """
    if exception is not None:
        exception_type = type(exception)

        if exception_type is pycurl.error or type(exception) is Exception:
            message = exception.args[1]
        else:
            message = str(exception)

        print('Error: (%s) %s' % (exception_type, message))

    file = __file__
    print('For help execute: '+ file + ' --help')
    sys.exit(1)


@click.command()
@click.option('--url', '-u', multiple=True, type=str,
              help='Url do solr que deseja listar os cores ou importar um.\n'
                   'Ex: ' +__file__+ ' -u solr.rentcars.lan:8983\n')
@click.option('--core', '-c', multiple=True, type=str,
              help='Nome do core que deseja listar o total de resultados.\n'
                   'Ex:  ' +__file__+ ' -u solr.rentcars.lan -c=tarifas_ws.\n'
                   'Se passar o parametro como all vai executar para todos os cores.\n')
@click.option('--import-core', '-i', default=False, type=bool, is_flag=True,
              help='Nome do core que deseja importar.\n'
                   'Ex:  ' +__file__+ ' -u solr.rentcars.lan -c=tarifas_ws.\n '
                   'Se passar o parametro como all vai executar para todos os cores.\n')
@click.option('--debug', '-d',default=False, type=bool,
              help='Ativa o modo de debug.Ex:  ' +__file__+ ' -u solr.rentcars.lan -c=regras -d =true.\n')

def main(url, core, import_core, debug):
    """
    Metodo principal do script

    :param url:
    :param core:
    :param import_core:
    :param debug:
    :return:
    """
    print("Executing SOLR status...")
    try:
        if len(url) > 0:
            url = url[0]
        else:
            url = None
        if len(core) > 0:
            core = core[0]
        else:
            core = None
    except Exception as detail:
        error(detail)


    if url is not None:
        url = url + ":8983"
        solrStatus = SolrStatus(url, core, import_core, debug)
        solrStatus.execute()
    else:
        error("Commands not present")



if __name__ == '__main__':
    main()
