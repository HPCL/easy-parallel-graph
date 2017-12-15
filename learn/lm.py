# Modified from 
# https://github.com/LighthouseHPC/lighthouse/tree/master/sandbox/ml/scikit
import sys
import numpy as np
import pandas
from sklearn import linear_model
from sklearn.model_selection import train_test_split
if len(sys.argv) != 2:
    print("usage: python {} datafile.csv".format(sys.argv[0]))
    sys.exit(2)
datafile = sys.argv[1]

data = pandas.read_csv(datafile)

# May want to look into OneHotEncoder for the categorical data

# Right now I just drop NaN's. Maybe look into Imputer, e.g.
# Imputer(missing_values='NaN', strategy='mean', axis=0)
data.dropna(axis=1, how='any', inplace=True)
a = len(data.T) - 1 # The last column is the label
X = data.iloc[:, range(0,a)]
Y = data.iloc[:,a]
X_train, X_test, Y_train, Y_test = train_test_split(X,Y, test_size = 0.34)
lm = linear_model.LinearRegression()
lm.fit(X_train, Y_train)
score = lm.score(X_test, Y_test)
print("Model R^2 = {}".format(lm.get_params(), score))
