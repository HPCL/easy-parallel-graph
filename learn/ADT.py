# Modified from 
# https://github.com/LighthouseHPC/lighthouse/tree/master/sandbox/ml/scikit
import sys
import numpy as np
import pandas
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score
from sklearn.metrics import classification_report
from sklearn import tree
if len(sys.argv) != 2:
    print("usage: python {} datafile.csv".format(sys.argv[0]))
    sys.exit(2)
datafile = sys.argv[1]

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

a = len(data.T) - 1 # The last column is the label
X = data.iloc[:, range(0,a)]
Y = data.iloc[:,a]
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)
clf_gini = DecisionTreeClassifier(criterion = "gini")
clf_gini.fit(X_train, Y_train)
#print(clf_gini)
gini_pred = clf_gini.predict(X_test)
#print(gini_pred)
clf_entropy = DecisionTreeClassifier(criterion = 'entropy')
clf_entropy.fit(X_train, Y_train)
entropy_pred = clf_entropy.predict(X_test)
#print(entropy_pred)

target_names = ['good', 'bad']
results = classification_report(Y_test, gini_pred, target_names)
print(results)
print(accuracy_score(Y_test, gini_pred))
