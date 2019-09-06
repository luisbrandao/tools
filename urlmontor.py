#!/bin/python3
import time
import sys
from urllib.request import urlopen
import hashlib
import urllib3
import csv,os
import logging

logger = logging.getLogger(__name__)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.WARN)

#Procedure to get hash value
def getHash(url):
    try:
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        http = urllib3.PoolManager()
        r = http.request('GET', url, timeout=1.0)
        the_page = str(r.status) + str(r.data[0:600])
        return hashlib.sha224(the_page.encode('utf-8')).hexdigest()
    except:
        change = "Unresponsive: " + _site + " won't respond"
        logger.info('%s' % change)
        return "unresponsive"

input_file="input.csv"
#This is input file
#example
#http://yahoo.com,hash
#http://linuxcursor.com,hash
#Temporary create outfile to store hash values
output_file="input.csv_"
#Open readonly input_file
input=open(input_file,"r")
data=csv.reader(input)
data=[row for row in data]
input.close()
#Open temporary file in write mode.
out=open(output_file,"w")
#Read line by line site name and its hash values.
for i in data:
    _site=i[0]
    _existing_hash=i[1]

    change = "INFO Site name " + _site + " Existing hash " + _existing_hash
    logger.debug('%s' % change)

    _new_hash=getHash(_site)

    change = "INFO new hash " + _new_hash
    logger.debug('%s' % change)

    if _existing_hash == _new_hash:
        change = "INFO Nothing to do"
        logger.debug('%s' % change)

        change = "Equal: " + _site + " haven't changed."
        logger.info('%s' % change)

        out.write(_site+","+_existing_hash )
        out.write("\n")
    else:
        change = "INFO Update csv file"
        logger.debug('%s' % change)
        out.write(_site + "," + _new_hash)
        out.write("\n")

        change = "Diferent: " + _site + " is diferent: " + _new_hash
        logger.warning('%s' % change)
out.close()
from os import remove
remove(input_file)
#Move temporary output file to input.csv for next run
os.rename(output_file, input_file)
