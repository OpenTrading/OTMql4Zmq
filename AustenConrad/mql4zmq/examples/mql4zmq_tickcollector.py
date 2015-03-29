# collect ticks and add matplotlib local timestamp as float  

import zmq
from datetime import datetime
from matplotlib.dates import date2num

context = zmq.Context()
socket = context.socket(zmq.SUB)

socket.connect("tcp://127.0.0.1:2027")

socket.setsockopt(zmq.SUBSCRIBE,"tick")


while True:
    string = socket.recv()
    print string + " " + str(date2num(datetime.now() ))   
    