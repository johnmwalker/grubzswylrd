import numpy as np

# Neural network structure
INPUT_NEURONS = 5
INTERNAL_NEURONS = 5
OUTPUT_NEURONS = 4

class NeuralNetwork:
    def __init__(self):
        # Initialize weights for a simple feed-forward network
        self.weights_input_internal = np.random.uniform(-1, 1, (INPUT_NEURONS, INTERNAL_NEURONS))
        self.weights_internal_output = np.random.uniform(-1, 1, (INTERNAL_NEURONS, OUTPUT_NEURONS))
    
    def activate(self, inputs):
        # Feed-forward activation
        internal = np.dot(inputs, self.weights_input_internal)
        outputs = np.dot(internal, self.weights_internal_output)
        return outputs
    