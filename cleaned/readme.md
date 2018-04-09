#Markdown Preview

run-realworld.sh

USAGE: ./run-workflow.sh [filename] [config] [num_threads]

1) [filename]: Should be same as dataset name

2) [config]:Has the following three-line pattern:
       1)dataset name 2)dataset homepage 3)dataset url

       eg:
       facebook_combined
       https://snap.stanford.edu/data/egonets-Facebook.html
       https://snap.stanford.edu/data/facebook_combined.txt.gz

3) [num_threads]: Should be an integer value between 0 and 99

usage example: ./run-workflow.sh email-Enron datasets.txt 10
