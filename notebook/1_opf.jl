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

# ╔═╡ abde8344-da3f-49b9-8777-53dcc79c5885
using PlutoUI, DataFrames

# ╔═╡ 3bb32d76-c930-4398-a1ed-21acd642d2a1
using PowerModelsDistribution

# ╔═╡ 04289cdd-cae4-46df-ab5b-18597a492a6e
using Ipopt

# ╔═╡ 81242eb0-e882-11f0-3500-6f0b3a4da832
md"""
# 1. Optimal Power Flow
This notebook provides a guide to the workflow of a basic _optimal power flow_ (OPF) problem. 
"""

# ╔═╡ 4612123b-a618-4e71-b1ef-a8314d5c4732
md"""
## 1.1 Package Installations
### PowerModelsDistribution
_PowerModelsDistribution.jl_ (PMD) is a _Julia/JuMP_-based package for modelling unbalanced (i.e., multiconductor) power networks.

It can be installed in Julia via the package manager:
"""

# ╔═╡ 70bb99f4-8648-4f55-a97f-6280ff077597
md"""
```julia
import Pkg
Pkg.add("PowerModelsDistribution")
```
"""

# ╔═╡ 151bb265-8d31-4acd-9fa8-69bc307f1e09
md"""
Or, within the Julia REPL:
"""

# ╔═╡ 96714d25-e8ee-4ed0-8b8d-70096dd76b6f
md"""
```Julia
]add PowerModelsDistribution
```
"""

# ╔═╡ c10e65b5-2275-4a5f-be9b-9aa27ac9309e
md"""
Or, within the notebook, Pluto will automatically install or remove packages while you work on your notebook. When you import a new package, Pluto will install it:
"""

# ╔═╡ 6ddde588-3f57-4161-a2ce-da07bb54f6f3
md"""
### Optimiser
PowerModelsDistribution depends on optimizers to solve Optimization problems.
[Known working optimisers](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/installation.html#Known-Working-Optimizers) include Artelys Knitro, CPLEX, Gurobi, Ipopt, etc.

Install an optimiser via the Julia package manager:
"""

# ╔═╡ c0df1bcd-866d-4d15-bd6f-e84879f3fc05
md"""
```Julia
import Pkg
Pkg.add("Ipopt)
```
"""

# ╔═╡ be69e983-4820-4a28-b46f-2cf3726863da
md"""
Or, within the Julia REPL:
"""

# ╔═╡ 950af500-ffde-4635-b91d-8bffa4a7112b
md"""
```Julia
]add Ipopt
```
"""

# ╔═╡ 57085e50-6215-4046-9580-a0bdfbf522ea
md"""
Or, within the notebook:
"""

# ╔═╡ 8a2db00f-c31c-4769-88e9-1b21604e0eb7
md"""
## 1.2 Import Network Data
"""

# ╔═╡ b80ae6b4-6ecb-460b-8186-796b407bd974
md"""
PMD supports input formats OpenDSS and JSON. Here we use OpenDSS as an example.
"""

# ╔═╡ 5891bc24-b8be-4eb5-bab3-d257cb8d692c
md"""
Select the case you want to explore from the dropdown list.
"""

# ╔═╡ 1ef764be-937e-4f4d-acab-7b9c20a9fb22
begin
	pmd_path = joinpath(dirname(pathof(PowerModelsDistribution)), "..")
	@bind case_file Select([
		# joinpath(pmd_path, "test/data/opendss/case3_balanced.dss") => "case3_balanced",
		# joinpath(pmd_path, "test/data/opendss/case3_unbalanced.dss") => "case3_unbalanced",
		joinpath(pmd_path, "test/data/en_validation_case_data/test_grounding.dss") => "case_EN_testgrounding"
	])
end

# ╔═╡ c8363635-59e5-40b3-873e-e2372b233a29
begin
	dss = open(case_file, "r") do f
		join(readlines(f), "\n")
	end

	importing_data_md = """
```dss
$(dss)
```
		
"""
	importing_data_md |> Markdown.parse
	
end

# ╔═╡ 1996dee2-a7cd-4e3d-8137-13f95202470a
md"""
### ENGINEERING data model
The ENGINEERING data model is the default data structure presented to users when no additional arguments are provided, and it is intended to be user-facing and to better reflect the engineering realities of the system.

It supports the following data categories:
- metadata (`name`, `conductor_ids`, `settings`, `files`, `conductors`, `data_model`...)
- node objects (`bus`, `load`, `voltage_source`...)
- edge objects (`line`...)
- data objects (`linecode`...)

"""

# ╔═╡ 0ad5d106-6f1b-4a8b-a32c-d1b86e487800
md"""
To parse data into the ENGINEERING data model structure, use the `parse_file` command.
"""

# ╔═╡ 16e8a286-140f-495b-8ea0-d9336a1bc880
md"""
OpenDSS cases with explicit neutral conductors model the grounding as a 'reactor' connected between different terminals of the same bus (i.e., from the 4th terminal to ground), which is not directly supported by PMD, since in PMD a reactor is mapped by default to a line.

The data model transformation `transform_loops!` is therefore used to address this issue by mapping the reactor to a shunt instead, or merging terminals when the reactor represents a short-circuit.
"""

# ╔═╡ 5d2c63ca-4d14-448a-ab84-1acd328e6631
# data_eng = parse_file(case_file)
data_eng = parse_file(case_file, transformations=[transform_loops!])  # for EN cases

# ╔═╡ 8b85d11f-4927-477f-838a-358841a86780
md"""
The resulting data structure is a Julia dictionary. 
"""

# ╔═╡ d4bdc84a-c9ee-49cf-901b-235eb9bc97c0
md"""
Note that this test case is _very_ unbalanced. To obtain a more realistic scenario, the loading is reduced by a factor of three.
"""

# ╔═╡ 4de76884-01c5-4532-b412-0d0fdb9f8d4e
begin
	for (_,load) in data_eng["load"]
		load["pd_nom"] *= 1/3
		load["qd_nom"] *= 1/3
	end
end

# ╔═╡ eb669f5a-74d4-43b8-9b7c-8b22f7a2c0cd
data_eng["load"]

# ╔═╡ b1508904-bed2-420c-a017-02ed0d8e446b
md"""
## 1.3 OPF specifications
"""

# ╔═╡ 33b46bec-141f-4644-be18-c009da691ffa
md"""
### Remove bounds
It is good practice to remove any bounds imported from the OpenDSS network data. These may be default bounds that are not appropriate for the specific case and can lead to infeasibility.
"""

# ╔═╡ 68eca637-f967-469f-96ba-4f9817932f1e
remove_all_bounds!(data_eng)

# ╔═╡ a7b22204-65a8-4a97-9907-bcb592d734d3
md"""
### Add bounds
"""

# ╔═╡ 84f6883f-c149-4dda-8284-8e27e6d09371
md"""
To specify absolute voltage bounds for each terminal individually, use `add_bus_absolute_vbounds!`:
"""

# ╔═╡ f91f18f1-0879-4cd5-a261-248c8b11b24a
add_bus_absolute_vbounds!(
	data_eng,
	phase_lb_pu = 0.8,
	phase_ub_pu = 1.2,
	neutral_ub_pu = 0.1
)

# ╔═╡ 56b2a552-a5cf-461e-80f1-5e9e050746e6
md"""
To apply symmetrical bounds for three-phase buses, use `add_bus_pn_pp_ng_vbounds!`
"""

# ╔═╡ 8fc46cdd-9b5d-4745-bd43-967cbf9016d7
add_bus_pn_pp_ng_vbounds!(
	data_eng, [1:3...], 4,  # data_eng::Dict{String,Any}, phase_terminals::Vector, neutral_terminal'
	pn_lb_pu = 0.9,
	pn_ub_pu = 1.1,
	pp_lb_pu = 0.9*sqrt(3),
	pp_ub_pu = 1.1*sqrt(3),
	ng_ub_pu = 0.1
)

# ╔═╡ 16aae4d7-bd5c-4776-b712-5a06010ca437
md"""
To apply voltage bounds to protect the connected 'units' (loads, generators, etc.), use `add_unit_vbounds!`:
"""

# ╔═╡ 466323bb-fb1d-455d-b8ca-8ba6e7a24767
add_unit_vbounds!(
	data_eng,
	lb_pu = 0.91,
	ub_pu = 1.09,
	delta_multiplier = sqrt(3),
	unit_comp_types = ["load"]
)

# ╔═╡ 172ee1fb-d376-4d17-9e8a-2e56302f8794
md"""
Applying all these transformations can result in redundant constraints. This issue is addressed in the data model transformation, which determines a minimal set of absolute and pairwise voltage constraints that imply all remaining constraints.
"""

# ╔═╡ 4582ec04-e5bf-4330-a1a5-e2360ca2550d
md"""
### Add a generator
Since the imported OpenDSS power flow case is fully determined and offers no degrees of freedom for optimisation, we add an additional generator to the problem.
"""

# ╔═╡ 56d00da8-70e9-4cdd-bebc-495c4bfcb698
begin
	data_eng["generator"] = Dict{String,Any}()
	data_eng["generator"]["g1"] = Dict{String,Any}(
		"status" => ENABLED,
		"bus" => "b2",
		"configuration" => WYE,
		"connections" => [2,4],
		"pg_lb" => [0.0],
		"pg_ub" => [20.0],
		"qg_lb" => [0.0],
		"qg_ub" => [0.0],
		"cost_pg_parameters" => fill(0.0,3)
	)
end

# ╔═╡ 0d2130a2-bb8e-46e6-9ffd-30967d92a558
md"""
## 1.4 OPF problem solving
"""

# ╔═╡ 200d0b60-f2fb-4b63-a92e-98518f4dc72e
md"""
### MATHEMATICAL Model
"""

# ╔═╡ e4d3b6e4-c9cb-4959-9b37-0d72cb332b3f
md"""
To begin, we convert the ENGINEERING model to the MATHEMATICAL model, which is then used to generate the JuMP model that is actually optimised.
"""

# ╔═╡ 3e59728f-b4ac-40ac-8ca4-07aaab471e55
data_math = transform_data_model(data_eng, kron_reduce=false, phase_project=false)

# ╔═╡ ba7ccd82-8483-4664-949b-b219529b50e0
md"""
Alternatively, the MATHEMATICAL model can be returned directly from the `parse_file` command with the `data_model` keyword argument.
"""

# ╔═╡ e87df404-a8ea-48b2-9ddb-450508c1d2b6
md"""
### Initialisation of Variables
Initilisation values for the voltage vairables are essential, as omitting them almost always leads to solver issues.
"""

# ╔═╡ a5ac92ed-bf25-462d-9cc6-b4a91297438e
md"""
This can be done using the method `add_start_vrvi!`, which infers the no-load voltage for each terminal in the network and adds initialisation properties to the MATHEMATICAL data model.
"""

# ╔═╡ 669188f9-8152-4de0-a053-8ec396e4977b
add_start_vrvi!(data_math)

# ╔═╡ cbfde825-ab88-4c8c-827f-637e48ff930f
md"""
### Solve the OPF Problem
"""

# ╔═╡ cb103b54-ec63-4873-a620-d47719875ad5
res = solve_mc_opf(data_math, IVRENPowerModel, Ipopt.Optimizer)

# ╔═╡ e6af87ec-096a-4883-b0fe-aacad097fbf3
md"""
Solutions are contained in the res dictionary.
"""

# ╔═╡ 2ab9dff1-29f8-4194-a0c9-6c6d9ed6a887
sol_math = res["solution"]

# ╔═╡ 39334765-ec2b-4b26-8a1b-eed3533a43e1
md"""
Transform the solutions back to the ENGINEERING data model using `transform_solution`
"""

# ╔═╡ d70bae86-ac74-41a6-b51b-ae23940f8349
sol_eng = transform_solution(sol_math, data_math)

# ╔═╡ 8486d5d3-3b7a-4cee-aca9-6d85723a5ffb
md"""
Now we can inspect the results easily.
"""

# ╔═╡ 0daecf19-8e49-44c3-be43-ff84f47de553
sol_eng["generator"]["g1"]["pg"]

# ╔═╡ 95fb92fe-fdbe-4904-b196-b3dd74102d51
md"""
The active power bounds of the gnerator are not binding (0 <= 5.15 <= 10.0). This indicates that another constraint is active, since g1 has zero cost and it would normally more optimal to dispatch more active power, with the source-bus generator supplying the remaining demand at the default price.

To investigate this, we inspect the voltage at bus b2. We obtain the voltage base from `data_math`, which allows us to examine the voltage in p.u.. This makes it easier to compare the values against the bounds specified before.
"""

# ╔═╡ ffa96319-97e0-40d6-b89d-fad98cf9392e
begin
	vbase_b2 = data_math["bus"][string(data_math["bus_lookup"]["b1"])]["vbase"]
	v_b2_pu = (sol_eng["bus"]["b2"]["vr"]+im*sol_eng["bus"]["b2"]["vi"])./vbase_b2
	vm_b2_pu = abs.(v_b2_pu)
end

# ╔═╡ 068b4103-c18f-476a-964a-7ac6c959693e
md"""
Alternatively, the p.u. values can be extracted directly from the MATHEMATICAL model (pay attention to the bus_lookup when mapping bus ids)
"""

# ╔═╡ 52c50b90-1a43-4a4f-b995-a61d4ceb1267
begin
v_b2_pu_ = sol_math["bus"]["1"]["vr"] + im*sol_math["bus"]["1"]["vi"]
vm_b2_pu_ = abs.(v_b2_pu_)
end

# ╔═╡ f46ddc9e-1c8f-4828-950a-9254752e8bb0
md"""
It turns out that the voltage magnitude constraint on the neutral terminal is binding.
"""

# ╔═╡ a0fe0cb9-df0a-49a3-ae4f-836c5116f71c
md"""
### Available Formulations for EN
Other available formulations that support explicit neutrals include:
- `IVRENPowerModel`: an exact non-linear formulation, with current flow variables (I) and rectangular voltage variables (VR)
- `IVRQuadraticENPowerModel`: an equivalent quadratic formulation
- `IVRReducedENPowerModel`: branch-reduced version of `IVRENPowerModel` (models only create explicit series current variables, and create the total current variables as linear expressions of those. Since branches tend to be the dominate component in number, this can lead to a big reduction in the number of variables.)
- `IVRReducedQuadraticENPowerModel`: the branch-reduced version of `IVRQuadraticENPowerModel`
- `ACRENPowerModel`: formulation with power flow variables
"""

# ╔═╡ 891845d9-7504-437c-b3ea-07d7db74d897
md"""
Comparison of formulations:
"""

# ╔═╡ 0989543e-7724-47a3-92d5-32ef813c8136
results = Dict{String,Any}()

# ╔═╡ 9b2f59ca-f539-4436-b284-ed70481da8a5
results["IVRENPowerModel"] = solve_mc_opf(data_math, IVRENPowerModel, Ipopt.Optimizer)

# ╔═╡ 08282fc5-63b6-49fa-8562-b6ddca671e3f
results["IVRQuadraticENPowerModel"] = solve_mc_opf(data_math, IVRQuadraticENPowerModel, Ipopt.Optimizer)

# ╔═╡ 349ca686-a08e-49da-83e5-b2b367dbe54d
results["IVRReducedENPowerModel"] = solve_mc_opf(data_math, IVRReducedENPowerModel, Ipopt.Optimizer)

# ╔═╡ e87ecef8-ac40-4a0f-aa57-33242524e8f9
results["IVRReducedQuadraticENPowerModel"] = solve_mc_opf(data_math, IVRReducedQuadraticENPowerModel, Ipopt.Optimizer)

# ╔═╡ 3097e1cf-735f-4fc5-9d9b-6523f18c9c1d
results["ACRENPowerModel"] = solve_mc_opf(data_math, ACRENPowerModel, Ipopt.Optimizer)

# ╔═╡ 60816c6e-5831-4319-b973-084b0e323c75
begin
	forms = sort([keys(results)...])
	sol_engs = Dict(f=>transform_solution(results[f]["solution"], data_math) for f in forms)
	DataFrame(
		"formulation" => forms,
		"objective value" => [results[f]["objective"] for f in forms],
		"g1 pg" => [sol_engs[f]["generator"]["g1"]["pg"][1] for f in forms]
	)
end

# ╔═╡ 7637e592-4200-402f-9ed2-70e5d20dc82e
md"""
The IVR formulations are preferred for EN models. This is because in EN models, the voltage magnitude cannot be bounded below for some terminals (the ones belonging to the neutral conductor). In a formulation with power flow variables, this means that KCL cannot be enforced for those terminals.

In short, ACR allows non-physical groundings of the neutral conductor, and is therefore a relaxation of the original problem.
It is not guaranteed that the objective value will be lower, because all problems are only solved to local optimality. And in fact, the ACR solution is very sensitive to changes in the initialization. The optional virtual groundings seem to introduce many potential local optima.
"""

# ╔═╡ eca93b63-b6bd-4e99-9651-60ef2d70cac9


# ╔═╡ a4b6b24d-fc3a-4954-8c7f-a726487c81fc
# isdefined(PowerModelsDistribution, :compute_mc_pf)

# ╔═╡ da7eda31-efbc-45d6-9739-947a24f00301
# res_pmd = compute_mc_pf(data_math; explicit_neutral=true, max_iter=100)

# ╔═╡ e22893a5-b991-4fee-97a5-c2106b1a3156
# const PMD = PowerModelsDistribution

# ╔═╡ 52870791-df14-4819-b666-8313c4356e38

# function find_bad_stamp(data_math; explicit_neutral=true)
#     # make sure start voltages exist
#     PMD.add_start_voltage!(data_math, coordinates=:rectangular, epsilon=0, explicit_neutral=explicit_neutral)
#     v_start = PMD._bts_to_start_voltage(data_math)

#     vbases = Dict(i => v * data_math["settings"]["voltage_scale_factor"] for (i, v) in data_math["settings"]["vbases_default"])
#     sbase  = data_math["settings"]["sbase_default"] * data_math["settings"]["power_scale_factor"]
#     bus_vbase, line_vbase = PMD.calc_voltage_bases(data_math, vbases)

#     comp_status_prop = Dict(x => "status" for x in ["load","shunt","storage","transformer","switch"])
#     comp_status_prop["branch"] = "br_status"
#     comp_status_prop["gen"]    = "gen_status"

#     for (comp_type, comp_interface) in PMD._CPF_COMPONENT_INTERFACES
#         for (id, comp) in data_math[comp_type]
#             comp[comp_status_prop[comp_type]] == 1 || continue

#             bts, nr_vns, y_prim, c_nl, c_tots = comp_interface(comp, v_start, explicit_neutral, line_vbase, sbase)

#             n_expected = length(bts) + nr_vns
#             n_actual   = size(y_prim, 1)

#             if n_expected != n_actual || size(y_prim, 1) != size(y_prim, 2)
#                 println("\n=== MISMATCH FOUND ===")
#                 println("comp_type = $comp_type, id = $id")
#                 println("length(bts) = $(length(bts)), nr_vns = $nr_vns  => expected N = $n_expected")
#                 println("size(y_prim) = $(size(y_prim))")
#                 # extra hints
#                 if haskey(comp, "connections")
#                     println("connections = $(comp["connections"]) (len=$(length(comp["connections"])))")
#                 end
#                 if haskey(comp, "f_connections") && haskey(comp, "t_connections")
#                     println("f_connections = $(comp["f_connections"]) (len=$(length(comp["f_connections"])))")
#                     println("t_connections = $(comp["t_connections"]) (len=$(length(comp["t_connections"])))")
#                 end
#                 if haskey(comp, "configuration")
#                     println("configuration = $(comp["configuration"])")
#                 end
#                 return (comp_type, id)
#             end
#         end
#     end

#     println("No mismatch found in component stamps.")
#     return nothing
# end




# ╔═╡ ddaede5d-e0a9-498f-9c88-9d078ea29a38
# find_bad_stamp(data_math; explicit_neutral=true)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PowerModelsDistribution = "d7431456-977f-11e9-2de3-97ff7677985e"

[compat]
DataFrames = "~1.8.1"
Ipopt = "~1.13.0"
PlutoUI = "~0.7.60"
PowerModelsDistribution = "~0.16.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.0"
manifest_format = "2.0"
project_hash = "bc9fcae8b9f5554822b86fec98f6ca337b32b6c8"

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

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

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

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "afb7c51ac63e40708a3071f80f5e84a752299d4f"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.39"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.Glob]]
git-tree-sha1 = "83cb0092e2792b9e3a865b6655e88f5b862607e2"
uuid = "c27321d9-0574-5035-807b-f59d2c89b15c"
version = "1.4.0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "1dc470db8b1131cfc7fb4c115de89fe391b9e780"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.12.0"

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

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays"]
git-tree-sha1 = "d05a696a5abaf9d1f8bce948ee53ed1533fadfdb"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.28.0"

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

    [deps.JuMP.weakdeps]
    DimensionalData = "0703355e-b756-11e9-17c0-8b28908087d0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

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

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

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

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

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

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

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

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

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

[[deps.Xorg_libpciaccess_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "4909eb8f1cbf6bd4b1c30dd18b2ead9019ef2fad"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.18.1+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╠═abde8344-da3f-49b9-8777-53dcc79c5885
# ╟─81242eb0-e882-11f0-3500-6f0b3a4da832
# ╟─4612123b-a618-4e71-b1ef-a8314d5c4732
# ╟─70bb99f4-8648-4f55-a97f-6280ff077597
# ╟─151bb265-8d31-4acd-9fa8-69bc307f1e09
# ╟─96714d25-e8ee-4ed0-8b8d-70096dd76b6f
# ╟─c10e65b5-2275-4a5f-be9b-9aa27ac9309e
# ╠═3bb32d76-c930-4398-a1ed-21acd642d2a1
# ╟─6ddde588-3f57-4161-a2ce-da07bb54f6f3
# ╟─c0df1bcd-866d-4d15-bd6f-e84879f3fc05
# ╟─be69e983-4820-4a28-b46f-2cf3726863da
# ╟─950af500-ffde-4635-b91d-8bffa4a7112b
# ╟─57085e50-6215-4046-9580-a0bdfbf522ea
# ╠═04289cdd-cae4-46df-ab5b-18597a492a6e
# ╟─8a2db00f-c31c-4769-88e9-1b21604e0eb7
# ╠═b80ae6b4-6ecb-460b-8186-796b407bd974
# ╟─5891bc24-b8be-4eb5-bab3-d257cb8d692c
# ╠═1ef764be-937e-4f4d-acab-7b9c20a9fb22
# ╠═c8363635-59e5-40b3-873e-e2372b233a29
# ╟─1996dee2-a7cd-4e3d-8137-13f95202470a
# ╟─0ad5d106-6f1b-4a8b-a32c-d1b86e487800
# ╟─16e8a286-140f-495b-8ea0-d9336a1bc880
# ╠═5d2c63ca-4d14-448a-ab84-1acd328e6631
# ╠═8b85d11f-4927-477f-838a-358841a86780
# ╟─d4bdc84a-c9ee-49cf-901b-235eb9bc97c0
# ╠═4de76884-01c5-4532-b412-0d0fdb9f8d4e
# ╠═eb669f5a-74d4-43b8-9b7c-8b22f7a2c0cd
# ╟─b1508904-bed2-420c-a017-02ed0d8e446b
# ╟─33b46bec-141f-4644-be18-c009da691ffa
# ╠═68eca637-f967-469f-96ba-4f9817932f1e
# ╟─a7b22204-65a8-4a97-9907-bcb592d734d3
# ╟─84f6883f-c149-4dda-8284-8e27e6d09371
# ╠═f91f18f1-0879-4cd5-a261-248c8b11b24a
# ╟─56b2a552-a5cf-461e-80f1-5e9e050746e6
# ╠═8fc46cdd-9b5d-4745-bd43-967cbf9016d7
# ╟─16aae4d7-bd5c-4776-b712-5a06010ca437
# ╠═466323bb-fb1d-455d-b8ca-8ba6e7a24767
# ╟─172ee1fb-d376-4d17-9e8a-2e56302f8794
# ╟─4582ec04-e5bf-4330-a1a5-e2360ca2550d
# ╠═56d00da8-70e9-4cdd-bebc-495c4bfcb698
# ╟─0d2130a2-bb8e-46e6-9ffd-30967d92a558
# ╟─200d0b60-f2fb-4b63-a92e-98518f4dc72e
# ╟─e4d3b6e4-c9cb-4959-9b37-0d72cb332b3f
# ╠═3e59728f-b4ac-40ac-8ca4-07aaab471e55
# ╠═ba7ccd82-8483-4664-949b-b219529b50e0
# ╠═e87df404-a8ea-48b2-9ddb-450508c1d2b6
# ╟─a5ac92ed-bf25-462d-9cc6-b4a91297438e
# ╠═669188f9-8152-4de0-a053-8ec396e4977b
# ╟─cbfde825-ab88-4c8c-827f-637e48ff930f
# ╠═cb103b54-ec63-4873-a620-d47719875ad5
# ╠═e6af87ec-096a-4883-b0fe-aacad097fbf3
# ╠═2ab9dff1-29f8-4194-a0c9-6c6d9ed6a887
# ╟─39334765-ec2b-4b26-8a1b-eed3533a43e1
# ╠═d70bae86-ac74-41a6-b51b-ae23940f8349
# ╟─8486d5d3-3b7a-4cee-aca9-6d85723a5ffb
# ╠═0daecf19-8e49-44c3-be43-ff84f47de553
# ╟─95fb92fe-fdbe-4904-b196-b3dd74102d51
# ╠═ffa96319-97e0-40d6-b89d-fad98cf9392e
# ╟─068b4103-c18f-476a-964a-7ac6c959693e
# ╠═52c50b90-1a43-4a4f-b995-a61d4ceb1267
# ╟─f46ddc9e-1c8f-4828-950a-9254752e8bb0
# ╟─a0fe0cb9-df0a-49a3-ae4f-836c5116f71c
# ╠═891845d9-7504-437c-b3ea-07d7db74d897
# ╠═0989543e-7724-47a3-92d5-32ef813c8136
# ╠═9b2f59ca-f539-4436-b284-ed70481da8a5
# ╠═08282fc5-63b6-49fa-8562-b6ddca671e3f
# ╠═349ca686-a08e-49da-83e5-b2b367dbe54d
# ╠═e87ecef8-ac40-4a0f-aa57-33242524e8f9
# ╠═3097e1cf-735f-4fc5-9d9b-6523f18c9c1d
# ╠═60816c6e-5831-4319-b973-084b0e323c75
# ╟─7637e592-4200-402f-9ed2-70e5d20dc82e
# ╠═eca93b63-b6bd-4e99-9651-60ef2d70cac9
# ╠═a4b6b24d-fc3a-4954-8c7f-a726487c81fc
# ╠═da7eda31-efbc-45d6-9739-947a24f00301
# ╠═e22893a5-b991-4fee-97a5-c2106b1a3156
# ╠═52870791-df14-4819-b666-8313c4356e38
# ╠═ddaede5d-e0a9-498f-9c88-9d078ea29a38
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
