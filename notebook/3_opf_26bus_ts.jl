### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ b1c1c6ea-7eff-4037-b9d7-7398960b1a5a
using DataFrames, Plots, PlutoUI, CSV

# ╔═╡ 90991ceb-7463-4195-89ba-f19addc98bf4
using PowerModelsDistribution

# ╔═╡ e2e689c8-005b-4702-9e89-51960bc5d8a2
using Ipopt

# ╔═╡ 020a6270-e9db-11f0-1b7a-b1763ebcb4bc
md"""
# 1. Optimal Power Flow_Time Series
This notebook provides a guide to the workflow of a basic _optimal power flow_ (OPF) problem (_OPF LV20 26bus ts_)
"""

# ╔═╡ e56eb14a-f50c-4006-b770-2c6e7827460e
md"""
## 1.1 Package Installations
### PowerModelsDistribution
_PowerModelsDistribution.jl_ (PMD) is a _Julia/JuMP_-based package for modelling unbalanced (i.e., multiconductor) power networks.
"""

# ╔═╡ 4bcdfb2e-daec-4891-80e7-55a364326715
md"""
It can be installed in Julia via the package manager:
```julia
import Pkg
Pkg.add("PowerModelsDistribution")
```
"""

# ╔═╡ 356c8180-b36b-468c-96bc-c0d5ab1ca9cc
md"""
Or, within the Julia REPL:
```Julia
]add PowerModelsDistribution
```
"""

# ╔═╡ 5b59f4d7-9722-47f2-af08-f58db03404fc
md"""
Or, within the notebook, Pluto will automatically install or remove packages while you work on your notebook. When you import a new package, Pluto will install it:
"""

# ╔═╡ c0dd561e-7589-4f3f-a61e-b84455f3002d
md"""
### Optimiser
PowerModelsDistribution depends on optimizers to solve Optimization problems.
[Known working optimisers](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/installation.html#Known-Working-Optimizers) include Artelys Knitro, CPLEX, Gurobi, Ipopt, etc.
"""

# ╔═╡ ec077690-07f7-4503-8cb1-2d5fcb39a0e0
md"""
Install an optimiser via the Julia package manager:
```Julia
import Pkg
Pkg.add("Ipopt)
```
"""

# ╔═╡ 91a4d782-debc-42d9-a162-26a2240b700f
md"""
Or, within the Julia REPL:
```Julia
]add Ipopt
```
"""

# ╔═╡ bfe19b99-88d1-4845-a1e4-f7e93293a64d
md"""
Or, within the notebook:
"""

# ╔═╡ 0d306a99-4a46-4be0-b023-16158f957b27
md"""
## 2. Load Network Data
"""

# ╔═╡ 3859310d-70f4-4440-a172-3ea46c6a5357
md"""
PMD supports input formats OpenDSS and JSON. Here we use OpenDSS as an example.
"""

# ╔═╡ 2c03e08e-1c1c-449a-b129-85584c2f20bd
case_path = "E:\\lvdata\\LV20_26bus_tsori"

# ╔═╡ cca88fe7-4f20-4bf2-8382-71ceb044cb21
file = "$case_path/Master.dss"

# ╔═╡ 305a6048-8ccb-49db-b4c9-ad5cc3ddac69
begin
	dss_content = open(file, "r") do f
		join(readlines(f), "\n")
	end

	importing_data_md = """
```dss
$(dss_content)
```
		
"""
	importing_data_md |> Markdown.parse
	
end

# ╔═╡ 36679476-2c00-4b72-94e4-793dd9843c8f
md"""
### ENGINEERING Data Model
The ENGINEERING data model is the default data structure presented to users when no additional arguments are provided, and it is intended to be user-facing and to better reflect the engineering realities of the system.

It supports the following data categories:
- metadata (`name`, `conductor_ids`, `settings`, `files`, `conductors`, `data_model`...)
- node objects (`bus`, `load`, `voltage_source`...)
- edge objects (`line`...)
- data objects (`linecode`...)
"""

# ╔═╡ 7e4198b6-bcfe-4e05-b042-a316d60d50d0
md"""
To parse data into the ENGINEERING data model structure, use the `parse_file` command.
"""

# ╔═╡ e1833566-cc0e-4a51-aa73-776815fe6e88
md"""
OpenDSS cases with explicit neutral conductors model the grounding as a 'reactor' connected between different terminals of the same bus (i.e., from the 4th terminal to ground), which is not directly supported by PMD, since in PMD a reactor is mapped by default to a line.

The data model transformation `transform_loops!` is therefore used to address this issue by mapping the reactor to a shunt instead, or merging terminals when the reactor represents a short-circuit.
"""

# ╔═╡ a9649838-9c8e-4e56-b215-23f0ee9e6b4d
md"""
The `time_series` data type is included in the ENGINEERING model and holds all time-series data.
To parse a file that includes time_series compenents:
"""

# ╔═╡ df52ae49-b425-4da0-badd-d3a740497423
# data_eng4w = parse_file(file, transformations=[transform_loops!])
data_eng4w_ts = parse_file(file, transformations=[transform_loops!]; time_series="daily")

# ╔═╡ 9919cc67-9bc4-422b-ba88-f37fba4b4e06
data_eng4w_ts["load"]

# ╔═╡ d744e51d-44e5-45fc-9007-8f05c6b8bf2e
data_eng4w_ts["time_series"]["ls1"]

# ╔═╡ 3aa20db0-8525-4e78-9aa7-1786fca40f96
md"""
The resulting data structure is a Julia dictionary. 
"""

# ╔═╡ 538c00c8-369e-4fd9-9c9b-5a9ebc5514b7
md"""
Under "load", there is a "time\_series" dictionary that contains ENGINEERING model variable names and references to the identifiers of root-level `time_series` objects.
"""

# ╔═╡ 60296604-c699-4da9-a832-c2e6084c11e3
md"""
## 1.3 OPF specifications
"""

# ╔═╡ 85dd0411-14f0-4307-9743-85a1d11104a9
md"""
### Remove bounds
It is good practice to remove any bounds imported from the OpenDSS network data. These may be default bounds that are not appropriate for the specific case and can lead to infeasibility.
"""

# ╔═╡ 5594b993-a765-4d15-b902-d65de44dc0db
# remove_all_bounds!(data_eng4w)
remove_all_bounds!(data_eng4w_ts)

# ╔═╡ aac526f2-586f-471a-bf9a-542917d8b20e
md"""
This can also be done in transformations, i.e., `transformations=[transform_loops!, remove_all_bounds!`]
"""

# ╔═╡ bd6c7d21-875a-40bd-aa04-ab9052e9961e
md"""
### Add bounds
"""

# ╔═╡ 78dbe6db-d34e-4cb1-8fd7-93f3d6c561f0
md"""
To specify absolute voltage bounds for each terminal individually, use `add_bus_absolute_vbounds!`
"""

# ╔═╡ 249f617c-de79-44ce-9f20-347559069d10
add_bus_absolute_vbounds!(
	data_eng4w_ts, #data_eng4w,
	phase_lb_pu = 0.8,
	phase_ub_pu = 1.2,
	neutral_ub_pu = 0.1
)

# ╔═╡ d3e97c3c-54cd-42c1-a04c-d3011b73c6c7
# data_eng4w["bus"]

# ╔═╡ 20f7b9d2-69c3-4457-9056-8bc28fe49c2b
md"""
To apply symmetrical bounds for three-phase buses, use `add_bus_pn_pp_ng_vbounds!`
"""

# ╔═╡ 3e5cfd11-ccd0-4a83-8752-6f19a626936e
add_bus_pn_pp_ng_vbounds!(
	data_eng4w_ts, [1:3...], 4, # data_eng4w, [1:3...], 4,
	pn_lb_pu = 0.9,
	pn_ub_pu = 1.1,
	pp_lb_pu = 0.9*sqrt(3),
	pp_ub_pu = 1.1*sqrt(3),
	ng_ub_pu = 0.1
)

# ╔═╡ dd950102-4c74-4767-b182-194e49b53505
# data_eng4w["bus"]

# ╔═╡ e8ffb4f9-1066-40f4-891c-46a760014ff9
md"""
To apply voltage bounds to protect the connected 'units' (loads, generators, etc.), use `add_unit_vbounds!`
"""

# ╔═╡ 39ea1d25-fd64-4034-a976-26284efc640c
add_unit_vbounds!(
	data_eng4w_ts, #data_eng4w,
	lb_pu = 0.91,
	ub_pu = 1.09,
	delta_multiplier = sqrt(3),
	unit_comp_types = ["load"]
)

# ╔═╡ 7701b127-2f9d-43d1-acff-9353c458535d
# data_eng4w["load"]

# ╔═╡ 3d67a531-4298-4540-9999-e303ddc8da8f
# ╠═╡ disabled = true
#=╠═╡
# loadscale = 1.0
  ╠═╡ =#

# ╔═╡ c21b7837-09f6-4859-8ba6-1e5aa7813e11
# @bind loadscale confirm(Slider(0.1:0.1:5; default=1, show_value=true))
@bind loadscale confirm(Slider(0.5:0.5:30; default=30
							   , show_value=true))

# ╔═╡ 8dd6f6fa-346f-4559-991b-2472ed104f65
loadscale

# ╔═╡ 3fe5993a-14cf-4e68-9df5-31f866d460f0
for (d, load) in  data_eng4w_ts["load"] #data_eng4w["load"]
	load["pd_nom"] .*= loadscale
	load["qd_nom"] .*= loadscale
end

# ╔═╡ abeefa98-272c-465e-967f-ef98f746d059
md"""
Applying all these transformations can result in redundant constraints. This issue is addressed in the data model transformation, which determines a minimal set of absolute and pairwise voltage constraints that imply all remaining constraints.
"""

# ╔═╡ 710405ab-821d-49bb-9d89-804ba2dab975
# data_eng4w["conductor_ids"] = 1:4
# begin
# 	data_eng4w["conductor_ids"] = 1:4
# 	data_eng4w["settings"]["sbase_default"] = 1
# 	data_eng4w["voltage_source"]["source"]["rs"] *=0
# 	data_eng4w["voltage_source"]["source"]["xs"] *=0
# end
begin
	data_eng4w_ts["conductor_ids"] = 1:4
	data_eng4w_ts["settings"]["sbase_default"] = 1
	data_eng4w_ts["voltage_source"]["source"]["rs"] *=0
	data_eng4w_ts["voltage_source"]["source"]["xs"] *=0
end

# ╔═╡ 0d120821-db42-4640-9d9c-bdd43485cb3c
md"""
To merge series of lines that connect only to buses with no other connections (i.e., strings of buses with no loads, generators, transformers, etc.), use `reduce_line_series!`. This function preserves the total length of the merged lines.
"""

# ╔═╡ 21ee4360-aaa5-4dd8-8170-4c31845dd845
# reduce_line_series!(data_eng4w)
reduce_line_series!(data_eng4w_ts)

# ╔═╡ d562405d-b4d8-4278-a35b-2f71ff3ffb96
md"""
### Add generators
We add additional generators to introduce some flexibility to the problem. (e.g., PV generation at some houses)
"""

# ╔═╡ 6a592f0f-db2c-473e-875c-3918b188ff7e
data_eng4w_ts["voltage_source"]["source"]

# ╔═╡ 48572a1f-ff32-4184-afbd-588d20486906
begin
	# data_eng4w["generator"] = Dict{String,Any}()
	data_eng4w_ts["generator"] = Dict{String,Any}()
	# data_eng4w["generator"]["g1"] = Dict{String,Any}(
	data_eng4w_ts["generator"]["g1"] = Dict{String,Any}(
		"status" => ENABLED,
		"bus" => "b2594",
		"configuration" => WYE,
		"connections" => [1,4],
		"pg_lb" => [0.0],
		"pg_ub" => [15.0], #15
		"qg_lb" => [0.0],
		"qg_ub" => [0.0],
		"cost_pg_parameters" => fill(0.0, 3)
	)
end

# ╔═╡ da87012b-f597-48cf-b0b0-f801cf9a7764
begin
	# data_eng4w["generator"]["g2"] = Dict{String,Any}(
	data_eng4w_ts["generator"]["g2"] = Dict{String,Any}(
		"status" => ENABLED,
		"bus" => "b1683",
		"configuration" => WYE,
		"connections" => [2,4],
		"pg_lb" => [0.0],
		"pg_ub" => [15.0], #
		"qg_lb" => [0.0],
		"qg_ub" => [0.0],
		"cost_pg_parameters" => fill(0.0, 3)
	)
end

# ╔═╡ 03410b4b-d43f-429b-ab08-f39c5a54c145
begin
	# data_eng4w["generator"]["g3"] = Dict{String,Any}(
	data_eng4w_ts["generator"]["g3"] = Dict{String,Any}(
		"status" => ENABLED,
		"bus" => "b1816",
		"configuration" => WYE,
		"connections" => [3,4],
		"pg_lb" => [0.0],
		"pg_ub" => [15.0], #
		"qg_lb" => [0.0],
		"qg_ub" => [0.0],
		"cost_pg_parameters" => fill(0.0, 3)
	)
end

# ╔═╡ aa2f2275-5848-4116-8d90-b17ef62ec3c8
begin
	# data_eng4w["generator"]["g4"] = Dict{String,Any}(
	data_eng4w_ts["generator"]["g4"] = Dict{String,Any}(
		"status" => ENABLED,
		"bus" => "b2813",
		"configuration" => WYE,
		"connections" => [1,4],
		"pg_lb" => [0.0],
		"pg_ub" => [15.0], #
		"qg_lb" => [0.0],
		"qg_ub" => [0.0],
		"cost_pg_parameters" => fill(0.0, 3)
	)
end

# ╔═╡ 251c871a-dd42-4f84-aa4f-c9eac5da867f
data_eng4w_ts["generator"]

# ╔═╡ 10a94dc6-0c67-436c-8c06-9e9091fea166
md"""
## 1.4 OPF Problem Solving
"""

# ╔═╡ 5376c602-d090-4395-b68a-eface06d9684
md"""
### MATHEMATICAL Model
We convert the ENGINEERING model to the MATHEMATICAL model, which is then used to generate the JuMP model that is actually optimised.
"""

# ╔═╡ 19d57178-b385-4cfd-bab0-6744af2df00a
md"""
To automatically create a multinetwork structure from an ENGINEERING model that contains `time_series` elements, we can use the `multinetwork` keyword argument in `transform_data_model`
"""

# ╔═╡ 028c553e-1568-4aa0-9449-78a7450c39ee
# data_math4w = transform_data_model(data_eng4w, kron_reduce=false, phase_project=false)
data_math4w_mn = transform_data_model(data_eng4w_ts, kron_reduce=false, phase_project=false; multinetwork=true)

# ╔═╡ 754be717-e6a4-472f-bde1-624f4f2a64e6
data_math4w_mn["map"]

# ╔═╡ 4530e5c4-3153-48c4-959a-beaf4d7b5f7a
# data_math4w["gen"]["1"]  

# ╔═╡ 74c27665-8724-4ae4-8bcd-543abdc033e3
# data_math4w["bus"]["1"]

# ╔═╡ 3ab36476-3ab1-4244-9080-5d4345515329
# data_math4w["bus_lookup"]
data_math4w_mn["bus_lookup"]

# ╔═╡ f36090b4-e18f-4c1c-a5da-f9cff132ec5f
md"""
Alternatively, the MATHEMATICAL model can be returned directly from the `parse_file` command with the `data_model` keyword argument.
"""

# ╔═╡ 6149973a-a3d7-4031-aaa7-0f859e34e367
md"""
### Initialisation of Variables
Initilisation values for the voltage vairables are essential, as omitting them almost always leads to solver issues.
"""

# ╔═╡ 09a196c3-1a4b-455c-adca-2ff83f2818d6
md"""
This can be done using the method `add_start_vrvi!`, which infers the no-load voltage for each terminal in the network and adds initialisation properties to the MATHEMATICAL data model.
"""

# ╔═╡ d7c6952e-c0a2-498c-bf23-0f53396a0539
# add_start_vrvi!(data_math4w)
add_start_vrvi!(data_math4w_mn)

# ╔═╡ 432d3d40-e052-4810-9a8a-8cdc53bccb82
# data_math4w["gen"]["2"]  #  source gen

# ╔═╡ 8329eb6c-58de-456b-b420-1876264d034d
# data_math4w["gen"]["1"]  # added pv gen

# ╔═╡ f8f75a22-e447-41dd-9653-043b5cc547ed
data_eng4w_ts["bus"]["b2824"]   # tx bus

# ╔═╡ b809bf62-b728-4e90-9fa6-6e7b1c22f44e
md"""
### Solve the OPF Problem
"""

# ╔═╡ 47b94ffb-1826-45fd-9fff-35fc5e6d2ac5
# res = solve_mc_opf(data_math4w, IVRENPowerModel, Ipopt.Optimizer)
res_mn = solve_mn_mc_opf(data_math4w_mn, IVRENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>2000, "tol" => 1e-6))

# ╔═╡ 02a0ab25-0f3e-47a8-803d-fe7720231360
sol_math4w_mn = res_mn["solution"]

# ╔═╡ 6a46c79b-feaf-4619-afcf-03c584c77c36
sol_math4w_mn["nw"]["1"]["bus"]

# ╔═╡ e905f6a0-7157-4a24-a57d-8411b19ab718
sol_math4w_mn["nw"]["1"]["gen"]

# ╔═╡ 761d285e-19a4-43a3-8b32-2b324b9f22a2
md"""
Transform the solutions back to the ENGINEERING data model using `transform_solution`
"""

# ╔═╡ 5b5d078d-4711-421e-80bb-7b9d98ef198b
# sol_eng4w = transform_solution(sol_math4w, data_math4w)
sol_eng4w_mn = transform_solution(sol_math4w_mn, data_math4w_mn)

# ╔═╡ 58d0a98d-aff4-4fc2-a599-4b7b30515ec4
md"""
### Inspect results
"""

# ╔═╡ 988b18ab-2dc9-42c8-8043-14c077a71cbd
begin
	df_ls1 = CSV.read("E:\\lvdata\\LV20_26bus_tsori\\load_profile_actual.csv", DataFrame; header=false)
	plot(df_ls1[:,1], xlabel="time step", ylabel="ls1")
end

# ╔═╡ 04f04fec-0d1d-49ca-a5c6-cbc8a764e181
sol_eng4w_mn["nw"]["1"]["load"]

# ╔═╡ ec723f09-f328-444d-89a1-8e255aa6ee2e
sol_eng4w_mn["nw"]["1"]["bus"]

# ╔═╡ 515eb102-f40e-412c-9457-7398cdeb9c77
sol_eng4w_mn["nw"]["1"]["bus"]["b2157"]

# ╔═╡ 0632488c-b8b1-442b-a115-cc69d9962e62
bus_vm(bus_sol) = hypot.(bus_sol["vr"], bus_sol["vi"])

# ╔═╡ d2b5a274-a1bc-49a5-beeb-3140b95356a0
md"""
**Select the phase to plot:**
"""

# ╔═╡ 86d897d7-dbfc-4964-af1e-d3da598e146a
@bind phase_idx Select([1, 2, 3, 4])

# ╔═╡ c436b591-ea92-46f6-ac89-9ee37839f7e4
function build_bus_timeseries_vm(sol_mn; phase_idx=phase_idx)
    # time slots (keys are strings like "1","2",...)
    nws = sort(parse.(Int, collect(keys(sol_mn["nw"]))))
    nw0 = string(first(nws))

    # bus ids (keys are strings like "b389", "b1250", ...)
    bus_ids = sort(collect(keys(sol_mn["nw"][nw0]["bus"])))
	bus_ids = filter(!=("b2157"), bus_ids)   # exclude transformer primary

    nb = length(bus_ids)
    nt = length(nws)
    V = Array{Float64}(undef, nb, nt)

    for (t_i, n) in enumerate(nws)
        bus_dict = sol_mn["nw"][string(n)]["bus"]
        for (b_i, bid) in enumerate(bus_ids)
            vm = bus_vm(bus_dict[bid])
            V[b_i, t_i] = vm[phase_idx]
        end
    end

    return nws, bus_ids, V
end

# ╔═╡ 1ccaaa4c-2c12-49a4-b62d-538dbfcd0f33
phase_idx

# ╔═╡ 1e339b7a-86a0-41ca-bb6d-8f95380e4959
nws, bus_ids, V = build_bus_timeseries_vm(sol_eng4w_mn; phase_idx=phase_idx)


# ╔═╡ f922d3ae-b25a-42e1-85a6-a5431ca18afb
begin
	p = plot()
	for (i, bid) in enumerate(bus_ids)
	    plot!(p, nws, V[i, :].*1000, label=bid)
	end
	xlabel!(p, "nw (time slot)")
	ylabel!(p, "Voltage magnitude (V)")
	ylims!(0,299)
	# ylims!(200, 255)
	p
end

# ╔═╡ 56a3deaa-5a33-4335-9889-514850b150e6
function build_bus_phase_timeseries_2(sol_mn, bid; phases=1:4)
    nws = sort(parse.(Int, collect(keys(sol_mn["nw"]))))
    nt  = length(nws)
    np  = length(phases)

    V = Array{Float64}(undef, np, nt)

    for (t_i, n) in enumerate(nws)
        bus_sol = sol_mn["nw"][string(n)]["bus"][bid]
        V[:, t_i] .= bus_vm(bus_sol)[phases]
    end

    return nws, V
end

# ╔═╡ 22a5de40-4736-46d2-aa8a-174241ba3918
# ╠═╡ disabled = true
#=╠═╡
# bid = "b389"             
  ╠═╡ =#

# ╔═╡ 9be02aef-7b80-4712-890d-b8dc8f65226e
bids = sort(collect(keys(sol_eng4w_mn["nw"]["1"]["bus"])))

# ╔═╡ 07ea0019-fbe2-4360-8c2a-4e739aa97158
md"""
(loads are located at `b2594.1`, `b1683.2`, `b1816.3`, `b2813.1`)

(generators are located at `b2594.1`, `b1683.2`, `b1816.3`, `b2813.1`)

**Select the bus to plot:**
"""

# ╔═╡ 31ec4cb7-d461-4ad7-96f0-5efb33fc2885
@bind bid Select(bids)

# ╔═╡ a011fdef-4a9d-4784-8de3-1e14367f9768
nws_2, Vph = build_bus_phase_timeseries_2(sol_eng4w_mn, bid; phases=1:4)

# ╔═╡ 74f18f35-9831-4899-9b7c-d3357c40c449
plot(nws, Vph'.*1000, label=["a" "b" "c" "n"], xlabel="nw (time slot)", ylabel="Voltage magnitude (V)")

# ╔═╡ 08879b7a-b977-429b-89a4-a8900fb09886
md"""
Now we can inspect the results easily.
"""

# ╔═╡ 393a5da1-60ad-4871-ac8c-e26b97e93d02
sol_eng4w_mn["nw"]["4"]["generator"]

# ╔═╡ ab3afda1-14af-445d-9af1-bf94d3deb3ee
# begin
# 	vbase_b2594 = data_math4w["bus"][string(data_math4w["bus_lookup"]["b2594"])]["vbase"]
# 	v_b2594_pu = (sol_eng4w["bus"]["b2594"]["vr"] + im*sol_eng4w["bus"]["b2594"]["vi"])./vbase_b2594
# 	vm_b3230_pu = abs.(v_b2594_pu)
# end

# ╔═╡ 47d59558-ffcd-4cb4-8a39-ba63a771330d
# ╠═╡ disabled = true
#=╠═╡
v_mag = Base.stack([hypot.(bus["vr"][1:4], bus["vi"][1:4]) for (b,bus) in res["solution"]["bus"]], dims=1)
# ???
  ╠═╡ =#

# ╔═╡ 167ee8d1-9028-4536-931a-95779255b544
# bus_lookup = data_math4w["bus_lookup"]

# ╔═╡ 8cc755fe-efdf-4b82-a52a-ed526027de02
# phys_bus_ids_eng = collect(keys(sol_eng4w["bus"]))

# ╔═╡ 7505605c-077d-49b3-be9a-7295cebfff4b
# ids = [bus_lookup[bid] for bid in phys_bus_ids_eng]

# ╔═╡ 207128e3-142d-40d8-a2d8-bd78d27518d8
# phys_bus_ids_math = string.(sort(ids))

# ╔═╡ 188d62c1-1007-40c1-a042-346c547395ea
# v_mag = stack([
# 	hypot.(sol_math4w["bus"][bid]["vr"][1:4],
# 		  sol_math4w["bus"][bid]["vi"][1:4])
# 	for bid in phys_bus_ids_math
# ], dims=1)

# ╔═╡ 63cbc4b4-58cc-4158-93c1-1aaf5c023ae8
# begin
# 	plot(v_mag, label=["a" "b" "c" "n"])
# 	# plot!([0; length(res["solution"]["bus"])], [0.9; 0.9], label="vmin")
# 	# plot!([0; length(res["solution"]["bus"])], [1.1; 1.1], label="vmax")
# 	# ylims!(0.95, 1.05)
# 	ylabel!("V (pu)")
# 	xlabel!("bus id (-)")
# end

# ╔═╡ df2c07bb-7386-42b5-baf4-289d8506884c
md"""
### Available Formulations for EN
Other available formulations that support [explicit neutrals](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/manual/formulations.html#Explicit-Neutral-Models) include:
- `IVRENPowerModel`: an exact non-linear formulation, with current flow variables (I) and rectangular voltage variables (VR)
- `IVRQuadraticENPowerModel`: an equivalent quadratic formulation
- `IVRReducedENPowerModel`: branch-reduced version of `IVRENPowerModel` (models only create explicit series current variables, and create the total current variables as linear expressions of those. Since branches tend to be the dominate component in number, this can lead to a big reduction in the number of variables.)
- `IVRReducedQuadraticENPowerModel`: the branch-reduced version of `IVRQuadraticENPowerModel`
- `ACRENPowerModel`: formulation with power flow variables
"""

# ╔═╡ 14688ff0-cc3f-4476-9e1f-dd2b4d824b96
md"""
Simple Comparison of solutions from different formulations:
"""

# ╔═╡ e0421aff-a28e-4f1c-b999-fa98c11cb228
# results = Dict{String,Any}()

# ╔═╡ ae222d13-da29-40c0-907d-4635fe829a98
# results["IVRENPowerModel"] = solve_mc_opf(data_math4w, IVRENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>1000, "tol" => 1e-6))

# ╔═╡ e3533557-c133-44b3-8acc-714659e3f10f
# results["IVRQuadraticENPowerModel"] = solve_mc_opf(data_math4w, IVRQuadraticENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>1000, "tol" => 1e-6))

# ╔═╡ 195a3145-af94-45a7-bca0-673eeb7927cd
# results["IVRReducedENPowerModel"] = solve_mc_opf(data_math4w, IVRReducedENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>1000, "tol" => 1e-6))

# ╔═╡ 0a144695-64ae-468a-9258-c9226ab0228c
# results["IVRReducedQuadraticENPowerModel"] = solve_mc_opf(data_math4w, IVRReducedQuadraticENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>1000, "tol" => 1e-6))

# ╔═╡ 73037cf2-aa38-49c4-8620-52fa96b746b1
# results["ACRENPowerModel"] = solve_mc_opf(data_math4w, ACRENPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>100, "tol" => 1e-6))

# ╔═╡ 3d2cc704-c0fd-477a-b194-4af61f1decd9
md"""
The IVR formulations are preferred for EN models. This is because in EN models, the voltage magnitude cannot be bounded below for some terminals (the ones belonging to the neutral conductor). In a formulation with power flow variables, this means that KCL cannot be enforced for those terminals.

In short, ACR allows non-physical groundings of the neutral conductor, and is therefore a relaxation of the original problem.
It is not guaranteed that the objective value will be lower, because all problems are only solved to local optimality. And in fact, the ACR solution is very sensitive to changes in the initialization. The optional virtual groundings seem to introduce many potential local optima.
"""

# ╔═╡ ff06fa90-7385-4617-a5e3-92015f3d285b
# results

# ╔═╡ 9f3caf01-ae2b-4ad8-943b-cc2b7f663b00
# begin
# 	forms = sort([keys(results)...])
# 	sol_engs4w = Dict(f=>transform_solution(results[f]["solution"], data_math4w) for f in forms)
# 	DataFrame(
# 		"formulation" => forms,
# 		"objective value" => [results[f]["objective"] for f in forms],
# 		"g1 pg" => [sol_engs4w[f]["generator"]["g1"]["pg"][1] for f in forms],
# 		"g2 pg" => [sol_engs4w[f]["generator"]["g2"]["pg"][1] for f in forms],
# 		"g3 pg" => [sol_engs4w[f]["generator"]["g3"]["pg"][1] for f in forms],
# 	)
# end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PowerModelsDistribution = "d7431456-977f-11e9-2de3-97ff7677985e"

[compat]
CSV = "~0.10.15"
DataFrames = "~1.8.1"
Ipopt = "~1.13.0"
Plots = "~1.40.7"
PlutoUI = "~0.7.60"
PowerModelsDistribution = "~0.16.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.0"
manifest_format = "2.0"
project_hash = "292a18e029ab761a26031cf36095579d283ee0a9"

[[deps.ASL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6252039f98492252f9e47c312c8ffda0e3b9e78d"
uuid = "ae81ac8f-d209-56e5-92de-9978fef736f9"
version = "0.1.3+0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "7fecfb1123b8d0232218e2da0c213004ff15358d"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.3"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "2ac646d71d0d24b44f3f8c84da8c9f4d70fb67df"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.4+0"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "TranscodingStreams"]
git-tree-sha1 = "84990fa864b7f2b4901901ca12736e45ee79068c"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.5"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "a656525c8b46aa6a1c76891552ed5381bb32ae7b"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.30.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "9d8a54ce4b17aa5bdce0ea5c34bc5e7c340d16ad"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.18.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+1"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "d9d26935a0bcffc87d2613ce14c527c99fc543fd"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.5.0"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d8928e9169ff76c6281f39a659f9bca3a573f24c"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.8.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4e1fe97fdaed23e9dc21d4d664bea76b65fc50a0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.22"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "473e9afc9cf30814eb67ffa5f2db7df82c3ad9fd"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.16.2+0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a4be429317c42cfae6a7fc03c31bad1970c310d"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+1"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d55dffd9ae73ff72f1c0482454dcf2ec6c6c4a63"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.5+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "83dc665d0312b41367b7263e8a4d172eac1897f4"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.4"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "8cc47f299902e13f90405ddb5bf87e5d474c0d38"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "6.1.2+0"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "3bab2c5aa25e7840a4b065805c0cdfc01f3068d2"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.24"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "301b5d5d731a0654825f1f2e906990f7141a106b"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.16.0+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "afb7c51ac63e40708a3071f80f5e84a752299d4f"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.39"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "2c5512e11c791d1baed2049c5652441b28fc6a31"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7a214fdac5ed5f59a22c2d9a885a16da1c74bbc7"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.17+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "fcb0584ff34e25155876418979d4c8971243bb89"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.4.0+2"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "629693584cef594c3f6f99e76e7a7ad17e60e8d5"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.7"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a8863b69c2a0859f2c2c87ebdc4c6712e88bdf0d"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.7+0"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "b0036b392358c80d2d2124746c2bf3d48d457938"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.82.4+0"

[[deps.Glob]]
git-tree-sha1 = "83cb0092e2792b9e3a865b6655e88f5b862607e2"
uuid = "c27321d9-0574-5035-807b-f59d2c89b15c"
version = "1.4.0"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a6dbda1fd736d60cc477d99f2e7a042acfa46e8"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.15+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "1dc470db8b1131cfc7fb4c115de89fe391b9e780"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.12.0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "5e6fe50ae7f23d171f44e311c2960294aaa0beb5"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.19"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "401e4f3f30f43af2c8478fc008da50096ea5240f"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.3.1+0"

[[deps.Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XML2_jll", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "3d468106a05408f9f7b6f161d9e7715159af247b"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.12.2+0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InfrastructureModels]]
deps = ["JuMP", "Memento"]
git-tree-sha1 = "f9c1f6bdac8ad3fca6fc24fcf68256958ad84c28"
uuid = "2030c09a-7f63-5d83-885d-db604e0e9cc0"
version = "0.7.8"

[[deps.InlineStrings]]
git-tree-sha1 = "8f3d257792a522b4601c24a577954b0a8cd7334d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.5"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.Ipopt]]
deps = ["Ipopt_jll", "LinearAlgebra", "OpenBLAS32_jll", "PrecompileTools"]
git-tree-sha1 = "b71d66023c875c28881af6749a41df3878bc3fb3"
uuid = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
version = "1.13.0"
weakdeps = ["MathOptInterface"]

    [deps.Ipopt.extensions]
    IpoptMathOptInterfaceExt = "MathOptInterface"

[[deps.Ipopt_jll]]
deps = ["ASL_jll", "Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "MUMPS_seq_jll", "SPRAL_jll", "libblastrampoline_jll"]
git-tree-sha1 = "b33cbc78b8d4de87d18fcd705054a82e2999dbac"
uuid = "9cc047cb-c261-5740-88fc-0cf96f7bdcc7"
version = "300.1400.1900+0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "b2d91fe939cae05960e760110b328288867b5758"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.6"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLFzf]]
deps = ["REPL", "Random", "fzf_jll"]
git-tree-sha1 = "82f7acdc599b65e0f8ccd270ffa1467c21cb647b"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.11"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "0533e564aae234aff59ab625543145446d8b6ec2"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "411eccfe8aba0814ffa0fdf4860913ed09c34975"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.3"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eac1206917768cb54957c65a615460d87b455fc1"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.1+0"

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays"]
git-tree-sha1 = "b76f23c45d75e27e3e9cbd2ee68d8e39491052d0"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.29.3"

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

    [deps.JuMP.weakdeps]
    DimensionalData = "0703355e-b756-11e9-17c0-8b28908087d0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eb62a3deb62fc6d8822c0c4bef73e4412419c5d8"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.8+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c602b1127f4751facb671441ca72715cc95938a"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.3+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "cd10d2cc78d34c0e2a3a36420ab607b611debfbb"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.7"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "27ecae93dd25ee0909666e6835051dd684cc035e"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+2"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a31572773ac1b745e0343fe5e2c8ddda7a37e997"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.41.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "2da088d113af58221c52828a80378e16be7d037a"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.5.1+1"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "321ccef73a96ba828cd51f2ab5b9f917fa73945a"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.41.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "5d4d2d9904227b8bd66386c1138cf4d5ffa826bf"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "0.4.9"

[[deps.METIS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2eefa8baa858871ae7770c98c3c2a7e46daba5b4"
uuid = "d00139f3-1899-568f-a2f0-47f597d42d70"
version = "5.1.3+0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MUMPS_seq_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "METIS_jll", "libblastrampoline_jll"]
git-tree-sha1 = "fc0c8442887b48c15aec2b1787a5fc812a99b2fd"
uuid = "d7ed1dd3-d0ae-5e8e-bfb4-87a502085b8d"
version = "500.800.100+0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "ForwardDiff", "JSON3", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test"]
git-tree-sha1 = "181c2611c7aa6a362fdf937b1e2af55e6691181f"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.48.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Memento]]
deps = ["Dates", "Distributed", "Requires", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "bb2e8f4d9f400f6e90d57b34860f6abdc51398e5"
uuid = "f28f55f0-a522-5efc-85c2-fe41dfb9b2d9"
version = "1.4.1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "22df8573f8e7c593ac205455ca088989d0a2c7a0"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.6.7"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "9b8215b1ee9e78a293f99797cd31375471b2bcae"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.3"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLAS32_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6065c4cff8fee6c6770b277af45d5082baacdba1"
uuid = "656ef2d0-ae68-5445-9ca0-591084a874a2"
version = "0.3.24+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+2"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "NetworkOptions", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "1d1aaa7d449b58415f97d2839c318b70ffb525a0"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.6.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7493f61f55a6cce7325f197443aa80d32554ba10"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.15+3"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c392fc5dd032381919e3b22dd32d6443760ce7ea"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.5.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e127b609fb9ecba6f201ba7ab753d5a605d53801"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.54.1+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "db76b1ecd5e9715f3d043cec13b2ec93ce015d53"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.44.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "41031ef3a1be6f5bbbf3e8073f210556daeae5ca"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.3.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "UnitfulLatexify", "Unzip"]
git-tree-sha1 = "f202a1ca4f6e165238d8175df63a7e26a51e04dc"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.40.7"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eba4810d5e6a01f612b948c9fa94f905b49087b0"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.60"

[[deps.PolyhedralRelaxations]]
deps = ["DataStructures", "ForwardDiff", "JuMP", "Logging", "LoggingExtras"]
git-tree-sha1 = "05f2adc696ae9a99be3de99dd8970d00a4dccefe"
uuid = "2e741578-48fa-11ea-2d62-b52c946f73a0"
version = "0.3.5"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PowerModelsDistribution]]
deps = ["CSV", "Dates", "FilePaths", "Glob", "Graphs", "InfrastructureModels", "JSON", "JuMP", "LinearAlgebra", "Logging", "LoggingExtras", "PolyhedralRelaxations", "SparseArrays", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "0fd46ba894971c0de0237296074b90a9c474618e"
uuid = "d7431456-977f-11e9-2de3-97ff7677985e"
version = "0.16.0"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "522f093a29b31a93e34eaea17ba055d850edea28"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.1"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "REPL", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "c5a07210bd060d6a8491b0ccdee2fa0235fc00bf"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "3.1.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "492601870742dcd38f233b23c3ec629628c1d724"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.7.1+1"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll"]
git-tree-sha1 = "e5dd466bf2569fe08c91a2cc29c1003f4797ac3b"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.7.1+2"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "1a180aeced866700d4bebc3120ea1451201f16bc"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.7.1+1"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "729927532d48cf79f49070341e1d918a65aba6b0"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.7.1+1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SPRAL_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "Libdl", "METIS_jll", "libblastrampoline_jll"]
git-tree-sha1 = "4f9833187a65ead66ed1907b44d5f20606282e3f"
uuid = "319450e9-13b8-58e8-aa9f-8fd1420848ab"
version = "2025.5.20+0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "ebe7e59b37c400f694f52b58c93d26201387da70"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.9"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "be8eeac05ec97d379347584fa9fe2f5f76795bcb"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.5"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f2685b435df2613e25fc10ad8c26dddb8640f547"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.6.1"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "95af145932c2ed859b63329952ce8d633719f091"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.3"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "b8693004b385c842357406e3af647701fe783f98"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.15"

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

    [deps.StaticArrays.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6ab403037779dae8c514bad259f32a447262455a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9d72a13a3f4dd3795a195ac5a44d7d6ff5f552ff"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.1"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "5cf7606d6cef84b543b483848d4ae08ad9832b21"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.3"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a3c1536470bf8c5e02096ad4853606d7c8f62721"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.2"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "6258d453843c466d84c17a58732dda5deeb8d3af"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.24.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    PrintfExt = "Printf"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"
    Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "975c354fcd5f7e1ddcc1f1a23e6e091d99e99bc8"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.6.4"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "85c7811eddec9e7f22615371c3cc81a504c508ee"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+2"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "80d3930c6347cfce7ccf96bd3bafdf079d9c0390"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.9+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "15e637a697345f6743674f1322beefbc5dcd5cfc"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.6.3+2"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "326b4fea307b0b39892b3e85fa451692eda8d46c"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.1+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "3796722887072218eabafb494a13c963209754ce"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.4+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "b5899b25d17bf1889d25906fb9deed5da0c15b3b"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.12+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c74ca84bbabc18c4547014765d194ff0b4dc9da"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.4+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "a4c0ee07ad36bf8bbce1c3bb52d21fb1e0b987fb"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.7+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "9caba99d38404b285db8801d5c45ef4f4f425a6d"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "6.0.1+0"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "a376af5c7ae60d29825164db40787f15c80c7c54"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.8.3+0"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll"]
git-tree-sha1 = "a5bc75478d323358a90dc36766f3c99ba7feb024"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.6+0"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "aff463c82a773cb86061bce8d53a0d976854923e"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.5+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "7ed9347888fac59a618302ee38216dd0379c480d"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.12+0"

[[deps.Xorg_libpciaccess_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "4909eb8f1cbf6bd4b1c30dd18b2ead9019ef2fad"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.18.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "e3150c7400c41e207012b41659591f083f3ef795"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.3+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "04341cb870f29dcd5e39055f895c39d016e18ccd"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.4+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f4fc02e384b74418679983a97385644b67e1263b"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll"]
git-tree-sha1 = "68da27247e7d8d8dafd1fcf0c3654ad6506f5f97"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "44ec54b0e2acd408b0fb361e1e9244c60c9c3dd4"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "5b0263b6d080716a02544c55fdff2c8d7f9a16a0"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.10+0"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f233c83cad1fa0e70b7771e0e21b061a116f2763"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.2+0"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "801a858fc9fb90c11ffddee1801bb06a738bda9b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.7+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "00af7ebdc563c9217ecc67776d1bbf037dbcebf4"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.44.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "gperf_jll"]
git-tree-sha1 = "431b678a28ebb559d224c0b6b6d01afce87c51ba"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.9+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6a34e0e0960190ac2a4363a1bd003504772d631"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.61.1+0"

[[deps.gperf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3516a5630f741c9eecb3720b1ec9d8edc3ecc033"
uuid = "1a1c6b14-54f6-533d-8383-74cd7377aa70"
version = "3.1.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4bba74fa59ab0755167ad24f98800fe5d727175b"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.12.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e17c115d55c5fbb7e52ebedb427a0dca79d4484e"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "141fe65dc3efabb0b1d5ba74e91f6ad26f84cc22"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "ad50e5b90f222cfe78aa3d5183a20a12de1322ce"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.18.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "07b6a107d926093898e82b3b1db657ebe33134ec"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.50+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "814e154bdb7be91d78b6802843f76b6ece642f11"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.6+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "35976a1216d6c066ea32cba2150c4fa682b276fc"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.0+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dcc541bb19ed5b0ede95581fb2e41ecf179527d2"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.6.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "fbf139bce07a534df0e699dbb5f5cc9346f95cc1"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.9.2+0"
"""

# ╔═╡ Cell order:
# ╠═b1c1c6ea-7eff-4037-b9d7-7398960b1a5a
# ╟─020a6270-e9db-11f0-1b7a-b1763ebcb4bc
# ╟─e56eb14a-f50c-4006-b770-2c6e7827460e
# ╠═4bcdfb2e-daec-4891-80e7-55a364326715
# ╠═356c8180-b36b-468c-96bc-c0d5ab1ca9cc
# ╠═5b59f4d7-9722-47f2-af08-f58db03404fc
# ╠═90991ceb-7463-4195-89ba-f19addc98bf4
# ╟─c0dd561e-7589-4f3f-a61e-b84455f3002d
# ╟─ec077690-07f7-4503-8cb1-2d5fcb39a0e0
# ╟─91a4d782-debc-42d9-a162-26a2240b700f
# ╟─bfe19b99-88d1-4845-a1e4-f7e93293a64d
# ╠═e2e689c8-005b-4702-9e89-51960bc5d8a2
# ╟─0d306a99-4a46-4be0-b023-16158f957b27
# ╟─3859310d-70f4-4440-a172-3ea46c6a5357
# ╠═2c03e08e-1c1c-449a-b129-85584c2f20bd
# ╠═cca88fe7-4f20-4bf2-8382-71ceb044cb21
# ╟─305a6048-8ccb-49db-b4c9-ad5cc3ddac69
# ╟─36679476-2c00-4b72-94e4-793dd9843c8f
# ╟─7e4198b6-bcfe-4e05-b042-a316d60d50d0
# ╟─e1833566-cc0e-4a51-aa73-776815fe6e88
# ╟─a9649838-9c8e-4e56-b215-23f0ee9e6b4d
# ╠═df52ae49-b425-4da0-badd-d3a740497423
# ╠═9919cc67-9bc4-422b-ba88-f37fba4b4e06
# ╠═d744e51d-44e5-45fc-9007-8f05c6b8bf2e
# ╟─3aa20db0-8525-4e78-9aa7-1786fca40f96
# ╟─538c00c8-369e-4fd9-9c9b-5a9ebc5514b7
# ╟─60296604-c699-4da9-a832-c2e6084c11e3
# ╟─85dd0411-14f0-4307-9743-85a1d11104a9
# ╠═5594b993-a765-4d15-b902-d65de44dc0db
# ╟─aac526f2-586f-471a-bf9a-542917d8b20e
# ╟─bd6c7d21-875a-40bd-aa04-ab9052e9961e
# ╟─78dbe6db-d34e-4cb1-8fd7-93f3d6c561f0
# ╠═249f617c-de79-44ce-9f20-347559069d10
# ╠═d3e97c3c-54cd-42c1-a04c-d3011b73c6c7
# ╟─20f7b9d2-69c3-4457-9056-8bc28fe49c2b
# ╠═3e5cfd11-ccd0-4a83-8752-6f19a626936e
# ╠═dd950102-4c74-4767-b182-194e49b53505
# ╟─e8ffb4f9-1066-40f4-891c-46a760014ff9
# ╠═39ea1d25-fd64-4034-a976-26284efc640c
# ╠═7701b127-2f9d-43d1-acff-9353c458535d
# ╠═3d67a531-4298-4540-9999-e303ddc8da8f
# ╠═c21b7837-09f6-4859-8ba6-1e5aa7813e11
# ╠═8dd6f6fa-346f-4559-991b-2472ed104f65
# ╠═3fe5993a-14cf-4e68-9df5-31f866d460f0
# ╟─abeefa98-272c-465e-967f-ef98f746d059
# ╠═710405ab-821d-49bb-9d89-804ba2dab975
# ╟─0d120821-db42-4640-9d9c-bdd43485cb3c
# ╠═21ee4360-aaa5-4dd8-8170-4c31845dd845
# ╟─d562405d-b4d8-4278-a35b-2f71ff3ffb96
# ╠═6a592f0f-db2c-473e-875c-3918b188ff7e
# ╠═48572a1f-ff32-4184-afbd-588d20486906
# ╠═da87012b-f597-48cf-b0b0-f801cf9a7764
# ╠═03410b4b-d43f-429b-ab08-f39c5a54c145
# ╠═aa2f2275-5848-4116-8d90-b17ef62ec3c8
# ╠═251c871a-dd42-4f84-aa4f-c9eac5da867f
# ╟─10a94dc6-0c67-436c-8c06-9e9091fea166
# ╟─5376c602-d090-4395-b68a-eface06d9684
# ╟─19d57178-b385-4cfd-bab0-6744af2df00a
# ╠═028c553e-1568-4aa0-9449-78a7450c39ee
# ╠═754be717-e6a4-472f-bde1-624f4f2a64e6
# ╠═4530e5c4-3153-48c4-959a-beaf4d7b5f7a
# ╠═74c27665-8724-4ae4-8bcd-543abdc033e3
# ╠═3ab36476-3ab1-4244-9080-5d4345515329
# ╟─f36090b4-e18f-4c1c-a5da-f9cff132ec5f
# ╟─6149973a-a3d7-4031-aaa7-0f859e34e367
# ╟─09a196c3-1a4b-455c-adca-2ff83f2818d6
# ╠═d7c6952e-c0a2-498c-bf23-0f53396a0539
# ╠═432d3d40-e052-4810-9a8a-8cdc53bccb82
# ╠═8329eb6c-58de-456b-b420-1876264d034d
# ╠═f8f75a22-e447-41dd-9653-043b5cc547ed
# ╟─b809bf62-b728-4e90-9fa6-6e7b1c22f44e
# ╠═47b94ffb-1826-45fd-9fff-35fc5e6d2ac5
# ╠═02a0ab25-0f3e-47a8-803d-fe7720231360
# ╠═6a46c79b-feaf-4619-afcf-03c584c77c36
# ╠═e905f6a0-7157-4a24-a57d-8411b19ab718
# ╟─761d285e-19a4-43a3-8b32-2b324b9f22a2
# ╠═5b5d078d-4711-421e-80bb-7b9d98ef198b
# ╟─58d0a98d-aff4-4fc2-a599-4b7b30515ec4
# ╠═988b18ab-2dc9-42c8-8043-14c077a71cbd
# ╠═04f04fec-0d1d-49ca-a5c6-cbc8a764e181
# ╠═ec723f09-f328-444d-89a1-8e255aa6ee2e
# ╠═515eb102-f40e-412c-9457-7398cdeb9c77
# ╠═0632488c-b8b1-442b-a115-cc69d9962e62
# ╠═c436b591-ea92-46f6-ac89-9ee37839f7e4
# ╟─d2b5a274-a1bc-49a5-beeb-3140b95356a0
# ╟─86d897d7-dbfc-4964-af1e-d3da598e146a
# ╟─1ccaaa4c-2c12-49a4-b62d-538dbfcd0f33
# ╠═1e339b7a-86a0-41ca-bb6d-8f95380e4959
# ╠═f922d3ae-b25a-42e1-85a6-a5431ca18afb
# ╠═56a3deaa-5a33-4335-9889-514850b150e6
# ╠═22a5de40-4736-46d2-aa8a-174241ba3918
# ╠═9be02aef-7b80-4712-890d-b8dc8f65226e
# ╟─07ea0019-fbe2-4360-8c2a-4e739aa97158
# ╟─31ec4cb7-d461-4ad7-96f0-5efb33fc2885
# ╠═a011fdef-4a9d-4784-8de3-1e14367f9768
# ╠═74f18f35-9831-4899-9b7c-d3357c40c449
# ╟─08879b7a-b977-429b-89a4-a8900fb09886
# ╠═393a5da1-60ad-4871-ac8c-e26b97e93d02
# ╠═ab3afda1-14af-445d-9af1-bf94d3deb3ee
# ╠═47d59558-ffcd-4cb4-8a39-ba63a771330d
# ╠═167ee8d1-9028-4536-931a-95779255b544
# ╠═8cc755fe-efdf-4b82-a52a-ed526027de02
# ╠═7505605c-077d-49b3-be9a-7295cebfff4b
# ╠═207128e3-142d-40d8-a2d8-bd78d27518d8
# ╠═188d62c1-1007-40c1-a042-346c547395ea
# ╠═63cbc4b4-58cc-4158-93c1-1aaf5c023ae8
# ╟─df2c07bb-7386-42b5-baf4-289d8506884c
# ╟─14688ff0-cc3f-4476-9e1f-dd2b4d824b96
# ╠═e0421aff-a28e-4f1c-b999-fa98c11cb228
# ╠═ae222d13-da29-40c0-907d-4635fe829a98
# ╠═e3533557-c133-44b3-8acc-714659e3f10f
# ╠═195a3145-af94-45a7-bca0-673eeb7927cd
# ╠═0a144695-64ae-468a-9258-c9226ab0228c
# ╠═73037cf2-aa38-49c4-8620-52fa96b746b1
# ╟─3d2cc704-c0fd-477a-b194-4af61f1decd9
# ╠═ff06fa90-7385-4617-a5e3-92015f3d285b
# ╠═9f3caf01-ae2b-4ad8-943b-cc2b7f663b00
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
