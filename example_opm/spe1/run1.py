from opm.simulators import BlackOilSimulator
from opm.io.parser import Parser
from opm.io.ecl_state import EclipseState
from opm.io.schedule import Schedule
from opm.io.summary import SummaryConfig

import os
basedir = os.path.dirname(__file__)
datafile = os.path.join(basedir, 'SPE1CASE1.DATA')

deck  = Parser().parse(datafile)
state = EclipseState(deck)
schedule = Schedule(deck, state)
summary_config = SummaryConfig(deck, state, schedule)

sim = BlackOilSimulator(deck, state, schedule, summary_config)
sim.step_init()
sim.step()
poro = sim.get_porosity()
poro = poro * 0.95
sim.set_porosity(poro)
sim.step()
sim.step_cleanup()