from bs4 import BeautifulSoup
import urllib2
import requests
import os
import csv

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

	lst=[]
	for i in rows:
	    columns=i.findAll('td')
	    value=columns[1::2]
	    for items in value:
		final=items.get_text()
		lst.append(final)

	fname=g_name
	filename="%s.csv" %fname
	path="easy-parallel-graph/learn/datasets/%s" %g_name 
	filepath=os.path.join(path,'features.csv')
	print filepath
	with open(filepath, 'wb') as myfile:
	    wr = csv.writer(myfile, quoting=csv.QUOTE_ALL)
	    wr.writerow(lst)

for pages,names in zip(url,graph_name):
	features(pages,names)
