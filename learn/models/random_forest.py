# -*- coding: utf-8 -*-
"""
Created on Wed Jul 12 12:25:40 2017
@author: A
"""

#This code is the random forest code for the different files given 
#Hopefully this works 
#Reference: https://jasdumas.github.io/2016-05-04-RF-in-python/
#Begin Code: 
import pandas 
import numpy as np

import matplotlib.pylab as plt
from treeinterpreter import treeinterpreter as ti
from sklearn.cross_validation import train_test_split
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
#----------------------------------------

target_names = ['good','bad']


#print(a)
#Begin actual Code: 

data = pandas.read_csv(datafile)
data = data[data.runtime != 0]


#--------------------classify dataset as good or bad
classification=[]
teps=[]
# m=data['runtime'].mean()
# print m
# for index, row in data.iterrows():
#     if row['runtime'] < m:
#         row['classification']='good'
#         classification.append(row['classification'])
#     else:
#         row['classification']='bad'
#         classification.append(row['classification'])

#-------------------------------
m = data['nedges'].divide(data['runtime']).mean()
#print m
#print data['runtime']
for index, row in data.iterrows():
    if row['nedges']/row['runtime'] > m/100:
        row['teps']=row['nedges']/row['runtime']
        row['classification']='good'
        classification.append(row['classification'])
        teps.append(row['teps'])
    else:
        row['teps']=row['nedges']/row['runtime']
        row['classification']='bad'
        classification.append(row['classification'])
        teps.append(row['teps'])
#--------------------------------
print np.std(teps)
data['teps']=pandas.Series(teps)
data['teps'].to_csv('teps.csv',na_rep='NA',index=False)
sd=data['teps'].std()
print sd
data=data.drop('teps', axis=1)
#print classification

data['classif']=pandas.Series(classification)

data['package'] = data.package.astype('category')
data['algorithm'] = data.algorithm.astype('category')
data['dataset'] = data.dataset.astype('category')
cat_columns = data.select_dtypes(['category']).columns
data[cat_columns] = data[cat_columns].apply(lambda x: x.cat.codes)
data=data.dropna()
#data=data.drop(['runtime'], axis=1)
#----------------------------------------------- Fit classifier


a = len(data.T) - 1
X = data.iloc[:,0:a] #the predictor class
#print(X)
Y = data.iloc[:,a] # The solutions 
#print(Y)
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)
print(X_train.shape, X_test.shape, Y_train.shape, Y_test.shape)
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

# ranking=classifier.predict_proba(X_test)
# print(classifier.predict(X_test))

# good_rank= ranking[:,1]
# rank_g=pandas.Series(good_rank)
# print rank_g
# X_test_df=pandas.DataFrame(X_test)
# X_test_df['proba']=rank_g

#---------------------------------- Analysis



importances = classifier.feature_importances_
std = np.std([tree.feature_importances_ for tree in classifier.estimators_],
             axis=0)
indices = np.argsort(importances)[::-1]
x_lab = [u'INFO', u'CUISINE', u'TYPE_OF_PLACE', u'DRINK', u'PLACE', u'MEAL_TIME', u'DISH', u'NEIGHBOURHOOD']

# Print the feature ranking
print("Confusion Matrix:")

#for f in range(X.shape[1]):
    #print("%d. feature %d (%f)" % (f + 1, indices[f], importances[indices[f]]))

# Plot the feature importances of the forest

plt.figure()
plt.title("Feature importances")
plt.xlabel('x_lab')
plt.bar(range(X.shape[1]), importances[indices],
       color="r", yerr=std[indices], align="center")
plt.xticks(range(X.shape[1]), indices)
plt.xlim([-1, X.shape[1]])
#plt.show()
#--------------------------
cm_lab=['good','bad']
cm = confusion_matrix(Y_test, predictions)



#cm.show()

print cm
#print Y_test
print predictions

#prepare for lm---------------------
#new_test_set = pandas.DataFrame(columns=['dataset','package','algorithm','nvertices','nedges','nthreads','Nodes.in.largest.WCC','Edges.in.largest.WCC','Nodes.in.largest.SCC','Edges.in.largest.WCC','Average.clustering.coefficient','Number.of.triangles','Fraction.of.closed.triangles','Diameter..longest.shortest.path.','X90.percentile.effective.diameter','classif'])
new_test_set = pandas.DataFrame(index=data.columns.copy())
new_bad_set = pandas.DataFrame(index=data.columns.copy())
for index, row in data.iterrows():
    if row['classif']== 'good':
        new_test_set=new_test_set.append(row)
    if row['classif']== 'bad':
        new_bad_set=new_bad_set.append(row) 




#new_test_set.dropna(axis=1, how='any', inplace=True)

new_test_set=new_test_set.dropna()
new_bad_set=new_bad_set.dropna()

#print new_bad_set['runtime'].min()

#print new_test_set['runtime'].min()
        

overall_nr = data['nedges'].divide(data['runtime']).min()
print overall_nr

overall_nr = data['nedges'].divide(data['runtime']).max()
print overall_nr

overall_nr = data['nedges'].divide(data['runtime']).mean()
print overall_nr

good_nr = new_test_set['nedges'].divide(new_test_set['runtime']).mean()
print good_nr





#new_test_set.to_csv('new_test.csv',na_rep='NA',index=False)
new_test_set.to_csv('rf_trained.csv',na_rep='NA',index=False)
new_bad_set.to_csv('rf_bad.csv',na_rep='NA',index=False)

new_test_set.to_csv('rf_good_runtime.csv',na_rep='NA',index=False)
new_bad_set.to_csv('rf_bad_runtime.csv',na_rep='NA',index=False)



