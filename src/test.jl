"""
Informally test Fish_ABM functions
Justin Angevaare
May 2015
"""

# Stock assumptions - survivorship and fecundity (proportion sexually mature and mean brood size at age)
s_a = stock_assumptions([0.35, 0.45, 0.4, 0.35, 0.2],
                        [0.1, 0.5, 0.9, 1, 1],
                        [7500, 15000, 20000, 22500, 25000])

# Agent assumptions - weekly mortality risks and growth (weeks until next stage)
a_a = agent_assumptions([[0.002 0.002 0.002]
                         [0.004 0.004 0.004]],
                         [0.005, 0.01, 0.01],
                         [19, 52, 104],
                         fill(0.0, (9,9,3)))

# Set movement transition probabilities
for i =1:3 a_a.movement[:,:,i] = eye(9) end

# Randomly generate a simple 3x3 environment_assumptions (id, spawning areas, habitat type and risk1)
e_a = environment_assumptions(reshape(1:9, (3,3)),
               rand(Bool, (3,3)),
               rand(1:2, (3,3)),
               rand(Bool, (3,3)))

# Must set initial age distribution of adults
s_db = stock_db(DataFrame(age_2=30000,
                          age_3=20000,
                          age_4=15000,
                          age_5=10000,
                          age_6=8000))

# Try the simulate function
a_db = simulate(25, s_db, s_a, a_a, e_a)
s_d
