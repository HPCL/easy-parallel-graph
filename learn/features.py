from bs4 import BeautifulSoup
import urllib2
import requests
import os
import csv
import sys

data_dir = "../experiment/datasets"
if len(sys.argv) > 2:
    print("usage: python features.py <data_dir> (default: ../experiments/datasets)")
    sys.exit(2)
if len(sys.argv) == 2:
    data_dir = str(sys.argv[1])

config='datasets.txt'
with open(config) as f:
    config_data=f.read().splitlines()

graph_name=config_data[::3]
url=config_data[1::3]
graph_zip=config_data[2::3] 

def features(graph_url,g_name):
    base_url = graph_url
    html_page = urllib2.urlopen(base_url)
    soup = BeautifulSoup(html_page, "html.parser")

    table = soup.find("table", id = "datatab")
    rows = table.findAll('tr')

    hdr=[]
    lst=[]
    for i in rows:
        columns=i.findAll('td')
        value=columns[1::2]
        for items in value:
            final=items.get_text()
            lst.append(final)
        hdr_value=columns[0::2]
        for items in hdr_value:
            final=items.get_text()
            hdr.append(final)

    fname=g_name
    filename="{}.csv".format(fname)
    path=os.path.join(data_dir, g_name)
    filepath=os.path.join(path,'features.csv')
    print("Writing features to {}".format(filepath))
    with open(filepath, 'wb') as myfile:
        wr = csv.writer(myfile, quoting=csv.QUOTE_ALL)
        wr.writerow(hdr)
        wr.writerow(lst)

for pages,names in zip(url,graph_name):
    features(pages,names)
