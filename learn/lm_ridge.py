# Modified from 
# https://github.com/LighthouseHPC/lighthouse/tree/master/sandbox/ml/scikit
import sys
import numpy as np
import pandas
from sklearn import linear_model
from sklearn.model_selection import train_test_split
from sklearn.linear_model import Ridge
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


X_train1, X_test1, Y_train1, Y_test1 = train_test_split(X_train,Y_train, test_size = 0.34)
model=Ridge(alpha = 1).fit(X_train1, Y_train1)
pred=model.predict(X_test1)
#print pred 
score_r = model.score(X_test, Y_test)
print("Model = {}, R^2 = {}".format(model.get_params(), score_r))