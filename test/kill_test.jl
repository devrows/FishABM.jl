#Test file for kill! function and subsequent mortality tracker

using FishABM

#only using this to populate agent database
function simulate_test(carrying_capacity::Vector, effort::Vector, bump::Vector,
  initStock::Vector, e_a::EnvironmentAssumptions, a_assumpt::AdultAssumptions,
  age_assumpt::AgentAssumptions, progress=true::Bool, limit=25000000::Int64)
  """
    Brings together all of the functions necessary for a life cycle simulation
  """
  @assert(all(carrying_capacity .> 0.), "There is at least one negative carrying capacity")
  @assert(length(effort)<=length(carrying_capacity), "The effort vector must be equal or less than the length of the simulation")
  @assert(length(bump)<=length(carrying_capacity), "The bump vector must be equal or less than the length of the simulation")
  years = length(carrying_capacity)
  #initialize the agent database and hash the enviro
  a_db = AgentDB(e_a); hashEnvironment!(a_db, e_a);

  #initialize stock, and
  globalPopulation = ClassPopulation(initStock, 0)
  #could add init stock to initialize it based off of the carrying capacity, maybe 50% bump?
  for i = 1:4
    injectAgents!(a_db, e_a.spawningHash, initStock[5-i], -age_assumpt.growth[((7-i)%4)+1])
  end

  #initialize the progress meter
  if progress
    totalPopulation = globalPopulation.stage[1]+globalPopulation.stage[2]+globalPopulation.stage[3]+globalPopulation.stage[4]
    progressBar = Progress(years*52, 30, " Year 1 (of $years), week 1 of simulation ($totalPopulation) fish, $(globalPopulation.stage[4]) adult fish) ", 30)
    print(" Year 1, week 1 ($(round(Int, 1/(years*52)))%) of simulation ($(globalPopulation.stage[4]) adult fish, $totalPopulation total) \n")
  end

  spawnWeek = 1; harvestWeek = 52;

  for y = 1:2
    for w = 1:52
      totalPopulation = globalPopulation.stage[1]+globalPopulation.stage[2]+globalPopulation.stage[3]+globalPopulation.stage[4]
      @assert(totalPopulation < limit, "> $limit agents in current simulation, stopping here.")

      if progress
        progressBar.desc = " Year $y (of $years), week $w of simulation ($totalPopulation) fish, $(globalPopulation.stage[4]) adult fish) "
        next!(progressBar)
        current = (y*52)+w
        if current%50 == 0
          total = (years+1)*52; percent = (current/total)*100;
          print(" Year $y, week $w ($(round(Int, percent))%) of simulation ($(globalPopulation.stage[4]) adult fish, $totalPopulation total) \n")
        end
      end
    end
  end

  return a_db
end

# Specify stock assumptions:
# * s_a.naturalmortality = Age specific mortality
# * s_a.halfmature = Age at 50% maturity
# * s_a.broodsize = Age specific fecundity
# * s_a.fecunditycompensation = Compensatory strength - fecundity
# * s_a.maturitycompensation = Compensatory strength - age at 50% maturity
# * s_a.mortalitycompensation = Compensatory strength - adult natural mortality
# * s_a.catchability = Age specific catchability
adult_a = AdultAssumptions([0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65],
                       5,
                       [2500, 7500, 15000, 20000, 22500, 27500, 32500],
                       2,
                       0.25,
                       1,
                       [0.00001, 0.00002, 0.000025, 0.000025, 0.000025, 0.000025, 0.000025])

# Specify environment assumptions:
# * e_a.spawning = Spawning areas
# * e_a.habitat = Habitat types
# * e_a.risk = Risk areas
spawnPath = string(split(Base.source_path(), "FishABM.jl")[1], "FishABM.jl/maps/LakeHuron_1km_spawning.csv")
habitatPath = string(split(Base.source_path(), "FishABM.jl")[1], "FishABM.jl/maps/LakeHuron_1km_habitat.csv")
riskPath = string(split(Base.source_path(), "FishABM.jl")[1], "FishABM.jl/maps/LakeHuron_1km_risk.csv")

enviro_a = initEnvironment(spawnPath, habitatPath, riskPath)



#a_db = AgentDB(e_a)
#e_a = generateEnvironment(spawnPath, habitatPath, riskPath)



# Specify agent assumptions:
# * a_a.naturalmortality =  Weekly natural mortality rate (by habitat type in the rows, and stage in the columns)
# * a_a.extramortality = Weekly risk mortality (by stage)
# * a_a.growth = Stage length (in weeks)
# * a_a.movement = Movement weight matrices
# * a_a.autonomy =  Movement autonomy

a_a = AgentAssumptions([[0.80 0.095 0.09 0.05]
                        [0.10 0.095 0.09 0.10]
                        [0.80 0.095 0.09 0.20]
                        [0.80 0.80 0.09 0.30]
                        [0.80 0.80 0.80 0.40]
                        [0.80 0.80 0.80 0.50]],
                       [0.0, 0.0, 0.0, 0.0],
                       [19, 52, 104, 0],
                       Array[[[0. 0. 0.]
                              [0. 1. 0.]
                              [0. 0. 0.]], [[1. 2. 1.]
                                            [1. 2. 1.]
                                            [1. 1. 1.]], [[1. 2. 1.]
                                                          [1. 1. 1.]
                                                          [1. 1. 1.]], [[1. 2. 1.]
                                                                        [1. 1. 1.]
                                                                        [1. 1. 1.]]],
                       [0., 0.5, 0.75, 0.5])



# Begin life cycle simulation, specifying:
# * Year specific carrying capacity (vector length determines simulation length)
# * Annual fishing effort
# * Population bump

using Distributions
k = rand(Normal(500000, 50000), 50)
effortVar = [0]
bumpVar = [100000]
initialStock = [500000, 1000000, 1500000, 2000000]

using ProgressMeter
adb = simulate_test(k, effortVar, bumpVar, initialStock, enviro_a, adult_a, a_a)

kill_test!(adb, enviro_a, a_a, 0)

adb[enviro_a.spawningHash[1]].alive

function kill_test!(agent_db::Vector, e_a::FishABM.EnvironmentAssumptions, a_a::FishABM.AgentAssumptions, week::Int64)
  """
    This function generates a mortality based on the stage of the fish and its corresponding natural mortality
    and its location within the habitat as described in EnvironmentAssumptions.
  """
  classLength = length((agent_db[1]).weekNum)

  for i = 1:length(e_a.spawningHash)
    for j = 1:classLength
      current_age = week - agent_db[e_a.spawningHash[i]].weekNum[j]
      stage = findCurrentStage(current_age, a_a.growth)
      if agent_db[e_a.spawningHash[i]].alive[j] > 0

        habitat = e_a.habitat[agent_db[e_a.spawningHash[i]].locationID]

        #Number of fish killed follows binomial distribution with arguments of number of fish alive
        #and natural mortality in the form of a probability
        killed = rand(Binomial(agent_db[e_a.spawningHash[i]].alive[j], a_a.naturalmortality[habitat, stage]))
        agent_db[e_a.spawningHash[i]].alive[j] -= killed
        if agent_db[e_a.spawningHash[i]].alive[j] > 0
          killed = rand(Binomial(agent_db[e_a.spawningHash[i]].alive[j], a_a.extramortality[stage]))
          agent_db[e_a.spawningHash[i]].alive[j] -= killed
        end
      end
    end
  end

  return agent_db
end

function findCurrentStage(current_age::Int64, growth_age::Vector)
  """
    Description: Simple function used to find the current stage of a cohort from
    the current age using the agent assumptions growth vector.

    Last update: May 2016
  """
  #Initialize the life stage number to 4
  currentStage = 4
  q = length(growth_age)-1

  #Most cohorts are likely to be adults, thus check stages from old to young
  while q > 0 && current_age < growth_age[q]
    currentStage = q
    q-=1
  end

  return currentStage
end
