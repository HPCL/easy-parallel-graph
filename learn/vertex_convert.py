import pandas
import numpy as np

import matplotlib.pylab as plt
import networkx as nx
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import classification_report
from sklearn import metrics
from sklearn import datasets
from sklearn.tree import export_graphviz
from sklearn.metrics import confusion_matrix
import six
from sklearn import tree
from sklearn.ensemble import ExtraTreesClassifier
from sklearn.metrics import recall_score
from sklearn.metrics import accuracy_score
from sklearn.ensemble import RandomForestClassifier
import time
import sys

#----------------------------------
if len(sys.argv) != 2:
    print("usage: python {} datafile.csv".format(sys.argv[0]))
    sys.exit(2)
datafile = sys.argv[1]
#---------------------------------------

g = np.loadtxt(datafile, dtype=int)	#read graph

rename={}
new=0

for i in range(0,len(g)):
	if g[i][0] not in rename:
		rename[g[i][0]]=new
		new=new+1
	if g[i][1] not in rename:
		rename[g[i][1]]=new
		new=new+1

for i in range(0,len(g)):
	g[i][0]=rename[g[i][0]]
	g[i][1]=rename[g[i][1]]

G=nx.from_edgelist(g)			#convert to networkx
nx.write_edgelist(G, "new_graph.txt" ,data = False) #write to file







