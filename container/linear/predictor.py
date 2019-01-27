# This is the file that implements a flask server to do inferences. It's the file that you will modify to
# implement the scoring for your own algorithm.

from __future__ import print_function

import os
import json
import pickle
from six import StringIO
import sys
import signal
import traceback
from joblib import dump, load
import flask
import re
from glob import glob
import pandas as pd
import numpy as np

prefix = "/opt/ml/"
model_path = os.path.join(prefix, "model")

# A singleton for holding the model. This simply loads the model and holds it.
# It has a predict function that does a prediction based on the model and the input data.


class ScoringService(object):
    model = None  # Where we keep the model when it's loaded

    @classmethod
    def get_model(cls):
        """Get the model object for this instance, loading it if it's not already loaded."""
        if cls.model == None:
            model_file_path = os.path.join(model_path, "regression_A.joblib")
            cls.model = load(model_file_path)
        return cls.model

    @classmethod
    def predict(cls, input):
        # we pass get_model for efficiency reasons
        models = {re.match('.+_([A-Z]).joblib', f).group(1): load(f) for f in glob("{}/*.joblib".format(model_path))}
        print("models:{}".format(models))
        n_features = input.shape[1] - 1
        predictions = []
        for row in input.values:
            model_prefix = row[0]
            data = np.array(row[1:]).reshape(1, n_features)
            single_pred = models.get(model_prefix).predict(data)
            print(model_prefix, int(single_pred))
            predictions.append(int(single_pred[0]))
        return predictions


# The flask app for serving predictions
app = flask.Flask(__name__)


@app.route("/ping", methods=["GET"])
def ping():
    """Determine if the container is working and healthy. In this sample container, we declare
    it healthy if we can load the model successfully."""
    health = (
        ScoringService.get_model() is not None
    )  # You can insert a health check here

    status = 200 if health else 404
    return flask.Response(response="\n", status=status, mimetype="application/json")


@app.route("/invocations", methods=["POST"])
def transformation():
    """Do an inference on a single batch of data. In this sample server, we take data as CSV, convert
    it to a pandas data frame for internal use and then convert the predictions back to CSV (which really
    just means one prediction per line, since there's a single column.
    """
    data = None

    # Convert from CSV to pandas
    if flask.request.content_type == "text/csv":
        data = flask.request.data.decode("utf-8")
        print(data)
        s = StringIO(data)
        data = pd.read_csv(s, header=None)
    else:
        return flask.Response(
            response="This predictor only supports CSV data",
            status=415,
            mimetype="text/plain",
        )

    print("Invoked with {} records".format(data.shape[0]))

    # Do the prediction
    predictions = ScoringService.predict(data)

    # Convert from numpy back to CSV
    out = StringIO()
    pd.DataFrame({"results": predictions}).to_csv(out, header=False, index=False)
    result = out.getvalue()

    return flask.Response(response=result, status=200, mimetype="text/csv")
