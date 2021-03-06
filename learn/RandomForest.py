# -*- coding: utf-8 -*-
# Modified from 
# https://github.com/LighthouseHPC/lighthouse/tree/master/sandbox/ml/scikit

#This code is the random forest code for the different files given 
#Hopefully this works 
#Reference: https://jasdumas.github.io/2016-05-04-RF-in-python/
#Begin Code: 
import pandas
import numpy as np
import matplotlib.pylab as plt
from sklearn.cross_validation import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import classification_report
from sklearn import metrics
from sklearn import datasets
from sklearn.ensemble import ExtraTreesClassifier
from sklearn.metrics import recall_score
from sklearn.metrics import accuracy_score
from sklearn.ensemble import RandomForestClassifier
import time

target_names = ['good', 'bad']

#Begin actual Code: 
datafile = input("Enter your datafile: ")
data = pandas.read_csv(datafile)

# Convert from real-valued (runtime) to categorical (good/bad)
def good_or_bad(x):
    m = min(x)
    # This isn't the best way to do it, but it prevents groupby
    # from returning a multiindex series
    return pandas.DataFrame(
            {'runtime' : x,
             'classification' : ['good' if y == m else 'bad' for y in x]})

# good = the lowest runtime package for an (algo,vertices,edges,threads) tuple
# bad = any other package's runtime
tmp = data.groupby(['algorithm', 'nvertices', 'nedges', 'nthreads'])['runtime'].apply(good_or_bad)
data['classification'] = tmp['classification']
del data['runtime'] # We only want categorial labels


a = len(data.T) - 1
X = data.iloc[:,0:a] #the predictor class
#print(X)
Y = data.iloc[:,a] # The solutions 
#print(Y)
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)
#print(X_train.shape, X_test.shape, Y_train.shape, Y_test.shape)
classifier = RandomForestClassifier(n_estimators = 100)
classifier = classifier.fit(X_train, Y_train)
#print(classifier)
predictions = classifier.predict(X_test)
#result = recall_score(Y_test, predictions, average = 'weighted')
results = metrics.classification_report(Y_test, predictions, target_names)
#mat = metrics.confusion_matrix(Y_test,predictions)
#sklearn.metrics.accuracy_score(Y_test, predictions)
print(results)
#print(result)
#print(mat)
print(time.clock())
