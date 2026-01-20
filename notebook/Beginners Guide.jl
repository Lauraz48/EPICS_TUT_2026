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

# ╔═╡ efb83906-40dc-4245-bc6a-b7c767b6e250
using CodeTracking, Revise, PlutoUI

# ╔═╡ 85895646-435a-437a-bb1e-0f0c0ed2a465
begin
	using PowerModelsDistribution
	import InfrastructureModels
	import JuMP
	import Ipopt
	import JSON
end

# ╔═╡ c4627de3-d3df-4b92-a969-464cd1d2cd96
using PowerModelsAnalytics

# ╔═╡ 4777a080-f501-11f0-13d5-d7408a561223
md"""
# Introduction to PowerModelsDistribution

This Notebook was designed for the following versions:

- `julia = "~1.6"`
- `PowerModelsDistribution = "~0.12"`
- `PowerModelsAnalytics = "~0.4.1"`

This notebook is a begginer's introduction to PowerModelsDistribution, an optimization-focused Julia library for quasi-steady state power distribution modeling, based on JuMP.jl, and part of the larger [InfrastructureModels.jl](https://github.com/lanl-ansi/InfrastructureModels.jl) ecosystem, which notably includes:

- [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl) : Transmission (single-phase positive sequence power networks) optimization
- [GasModels.jl](https://github.com/lanl-ansi/GasModels.jl) : Natural Gas pipeline optimization (includes Steady-state and Transient optimization)
- [WaterModels.jl](https://github.com/lanl-ansi/WaterModels.jl) : Water network steady-state optimization

Details about PowerModelsDistribution.jl can be found in our [PSCC Conference Proceedings paper](https://doi.org/10.1016/j.epsr.2020.106664).
"""

# ╔═╡ a30ec1bc-2e4f-4497-868a-7b064b010b8a
md"The following packages are used for notebook features only and do not relate to tutorial content"

# ╔═╡ 1c74137d-1c4c-4726-9e62-dcee32e163b1
md"""
This notebook will make use of the following packages in various places
"""

# ╔═╡ 84482fb7-b96f-4cb0-9d0d-dee03d31dbe4
IM = InfrastructureModels

# ╔═╡ b2993319-0c2d-414d-a86e-3e470b34e0bc
md"""
## Case Section

This notebook can apply to different data sets, select a case for examples below from the cases included in the PMD unit testing suite:
"""

# ╔═╡ 07f71542-ee2a-41f6-ab97-8a852bf4c7bd
begin
	pmd_path = joinpath(dirname(pathof(PowerModelsDistribution)), "..")
	@bind case_file Select([
			joinpath(pmd_path, "test/data/opendss/case3_balanced.dss") => "case3_balanced",
			joinpath(pmd_path, "test/data/opendss/case3_unbalanced.dss") => "case3_unbalanced",
			joinpath(pmd_path, "test/data/opendss/case3_balanced_battery.dss") => "case3_balanced_battery",
			joinpath(pmd_path, "test/data/opendss/case5_phase_drop.dss") => "case5_phase_drop",
			joinpath(pmd_path, "test/data/opendss/ut_trans_2w_yy_oltc.dss") => "ut_trans_2w_yy_oltc",
			joinpath(pmd_path, "test/data/opendss/case3_balanced_battery.dss") => "case3_balanced_battery",
		])
end

# ╔═╡ 3fe558b3-1222-4bdc-b126-18e7d4ede75e
begin
	dss = open(case_file, "r") do f
		join(readlines(f),"\n")
	end

	importing_data_md = """
# Importing Data

PMD supports two input formats, __OpenDSS__ and __JSON__. We strongly recommend OpenDSS for new users, as JSON is intended primarily for data models and results portability between colleagues working on the same problem, and OpenDSS is appropriate for specifying new networks.

Below is an example of an OpenDSS specification for feeder $(case_file):

```dss
$(dss)
```

Data is imported via the `parse_file` command, which we will use further down in the tutorial.
"""

	importing_data_md |> Markdown.parse
end

# ╔═╡ f84697c2-cb05-4b57-987e-f00e2ae39c20
md"""
# Data Models

In PMD, there are two data models, an `ENGINEERING` data model, which is meant to be user facing, and to better reflect the engineering realities of the system, and a `MATHEMATICAL` data model, which reflect the mathematical representation of the system.

Data models are identified by a key in the data dictionary, `"data_model"`, whose values are `ENUM`s:

- $(ENGINEERING)
- $(MATHEMATICAL)

## ENGINEERING data model

Full specification of the `ENGINEERING` data model can be found in our [documentation](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/eng-data-model/).

The engineering data model supports several broad categories of data:

- metadata
- node objects
- edge objects
- data objects

"""

# ╔═╡ aeb4a5bf-c8d8-447c-870a-f9c9f7c21e75
eng = parse_file(case_file)

# ╔═╡ ee3fa83d-8480-4266-9c02-1f59c9803c81
"""
### Metadata

Metadata is mostly straight-forward, containing meta information about the feeder, on the parse, and what type of data model is currently being represented.

For `case3_balanced_eng` the following metadata fields are available:

- `name`
- `conductor_ids`
- `settings`
- `files`
- `conductors`
- `data_model`
""" |> Markdown.parse

# ╔═╡ 67d3c28e-a3c8-419c-89ea-ac5fa6cfa18e
Dict{String,Any}(k => eng[k] for k in ["settings", "conductor_ids", "files", "name", "data_model"])

# ╔═╡ 96188c03-1d47-4ce9-a3a8-6b2f629bd4db
md"""
`settings` and `data_model` are the most important metadata, required for solving any type of optimization problem.

`data_model` is self-explanatory, but `settings` requires some explanation. First and foremost, `settings` contains the information needed to calculate the voltage bases for all of the buses in the network. When parsing from a DSS file, these are not explicitly stated, and must be extrapolated from the voltage at the source, and the network must be walked-through, and in a case with transformers the new voltage base is adjusted on the other side of the transformer.

Inside `settings`, scalars can also be set, which might be valuable if, _e.g._, the power or voltage values are being scaled into inappropriate per-unit values.

Finally, `settings` also contains `base_frequency`, which by default is 60 Hz, but can be specified in OpenDSS, and is valuable to know if, for example, you are working with data from Europe, which might have a base frequency of 50 Hz.
"""

# ╔═╡ c6649922-5069-41ae-bf86-472f51d20387
md"""
### Distribution Assets

These consist of the actual physical assests in the distribution feeder, including the buses, which are the connective nodes on the network graph, lines, which are the fundamental edges, and others. In `case3_balanced_eng` there is the following asset types:

- `bus`
- `line`
- `load`
- `voltage_source`
"""

# ╔═╡ 9e1cddb5-7a34-4122-95fb-ab4d9cbe22f9
Dict{String,Any}(k => eng[k] for k in ["bus", "line", "load", "voltage_source"])

# ╔═╡ 23231012-e964-4b7f-a102-44f7add8d251
md"""
Voltage sources are representations of the substation at which the feeder is connected. By default in dss, there is a default voltage source called `"source"`, which has some default values.
"""

# ╔═╡ 110ec8c3-19e7-469a-86f7-c1b702d32e7c
md"""
### Data objects

Data objects are things that affect and/or modify other objects, so linecodes, transformer codes (xfmrcode), or time series data.

In `eng`, only the following data object exists:

- `linecode`
"""

# ╔═╡ b9bc6e55-052a-4900-990e-2834e1787069
Dict{String,Any}(k => eng[k] for k in ["linecode"])

# ╔═╡ ee4bc59d-49c2-452e-84c9-60916e85d008
md"""
### Enums

In the `ENGINEERING` data model we make heavy use of a Julia data structure called an `Enum`, or an Enumerated Type. This is a type whose values are enumerated, starting with 0. This has the benefit of being much more readable by the user.

If you are familiar with JuMP, you probably are already used to Enums `TerminationStatusCode` and `ResultStatusCode`, which we import explicitly from JuMP.MOI and export, for easy access by the user when using `using PowerModelsDistribution`.

For example, instead of a switch `state` having the possible values 0 or 1, instead we created an enumerated type `SwitchState`, with values `OPEN` (0) and `CLOSED` (1).

We follow the convention that Enum values are all uppercase.

Enums can be cast into their integer values easily:
"""

# ╔═╡ d41d8592-3ecf-4245-bbe5-59320dfa746a
Int(OPEN)

# ╔═╡ def57270-e13d-4351-9773-dedd6a8e03d8
md"Integers can be converted back to Enums just as easily..."

# ╔═╡ a46e7ce7-6a6a-4238-aa1f-53a7eb4cb980
SwitchState(0)

# ╔═╡ e349cba9-a37d-4d2d-95c4-8c75488871f1
md"The following Enum types exist in PMD"

# ╔═╡ d837c1da-6c1e-4a72-a955-3fc1f8ff013b
PowerModelsDistributionEnums

# ╔═╡ 7888ea50-fe69-4277-8123-67f0dee04528
md"and the following enum values exist currently in PMD (excluding those imported from JuMP.MOI):"

# ╔═╡ b4bce3c1-440d-4124-af38-3933189da721
[n for n in names(PowerModelsDistribution) if isa(getproperty(PowerModelsDistribution, n), Enum) && !isa(getproperty(PowerModelsDistribution, n),Union{TerminationStatusCode,ResultStatusCode})]

# ╔═╡ f6d6b1cb-52db-47cf-a4ed-c73062d1b4ec
md"""
Some common examples when you will typically see Enums include:

- `status`, on all components,
- `data_model`, at the root level,
- `dispatchable`, on things like switches, loads, and shunts, which indicate an ability to change their "state", like shedding the load, or opening or closing the switch
- `configuration`, which indicates the connection type, `WYE` or `DELTA`
- `model`, e.g., on loads, which can indicate the type of load, like constant `POWER`, `CURRENT`, `IMPEDANCE`, etc.
"""

# ╔═╡ 88545c6a-1d29-4159-a3dc-71e81fc0cdb2
md"""
### Transformations

Transformations are one of the most powerfull aspects of using the engineering model, because items are more simple and self-contained rather than decomposed, editing before transformation into a mathematical model is significantly more straightforward.

The best example of this is Kron reduction, which is still done by default, where it would be too complicated at the mathematical level, requiring significant changes to the transformer models, for example.

Some simple examples that we commonly use involve settings better OPF bounds:
"""

# ╔═╡ d72af654-08f2-423a-9eb2-29923fc3edc4
begin
	apply_voltage_bounds!(eng; vm_lb=0.9, vm_ub=1.1)
	apply_voltage_angle_difference_bounds!(eng, 1)
end

# ╔═╡ 06aa16fd-ec03-4806-8c16-6e5e9db93c23
md"""
Some other valuable transformations built into PMD are:

- `make_lossless` (will strip loss models on engineering assets that contain them, e.g., voltage sources or switches)
- `remove_all_bounds` (will remove all bounds, e.g., those parsed in from the raw dss file)
"""

# ╔═╡ 2fa4a333-dc26-447a-9ddf-0d20b97233c2
"""
```julia
$(@code_string remove_all_bounds!(eng))
```
""" |> Markdown.parse

# ╔═╡ 1af072c6-1e55-479e-be14-6e4b4f7fe234
md"""
## MATHEMATICAL data model

The mathematical data model is a transformation of the engineering components into ones which we can more easily represent in the optimization model.
"""

# ╔═╡ ee4d2030-18fc-4cb7-b641-d002c8d9de1a
math = transform_data_model(eng)

# ╔═╡ b14722db-636d-46bc-95a5-5ab92796b742
md"""
The mathematical model can also be loaded directly via `parse_file`:

```julia
parse_file(case_file; data_model=MATHEMATICAL)
```

In some cases, the transformations are straight-forward, 1-to-1 type of conversions, where we convert to more optimization-friendly fields and units, like with lines -> branches, or loads -> loads.

But, some other components' transformations are less obvious, like voltage sources.
"""

# ╔═╡ a5d53b72-b1ce-40cb-be9d-2f755e3df514
@bind source_id_select Select(["$type.$name" for type in pmd_eng_asset_types for name in keys(get(eng, type, Dict()))])

# ╔═╡ 2fae4366-c36f-4bc8-a766-50096be2282c
filter(
	x->!isempty(x.second),
	Dict(
		type => Dict(
				name => obj
				for (name,obj) in get(math, type, Dict())
					if source_id_select == obj["source_id"]
				) for type in pmd_math_asset_types
		)
)

# ╔═╡ 179238e2-3f4e-4f11-b7aa-1eaf6e2280aa
md"""
Note: All objects have the field `source_id`, that is meant to indicate where a `MATHEMATICAL` object originated from with the `ENGINEERING` model.
"""

# ╔═╡ 6ea6de86-caea-40af-80cd-2d2a5264adca
md"""
The reason for this is that some more complex objects can be decomposed into multiple mathematical objects. In the case of this voltage source, there is a non-zero source impedance, and rather than creating an entirely new mathematical object, we can decompose it into a generator with unlimited power bounds, and into an impedance branch, with a connecting bus.
"""

# ╔═╡ 741b9a2b-cf14-4d2d-a3a2-e8157d32723d
"""
### Componnent ID Format

In the engineering model, all component ids can be arbitrary strings, making it easier to navigate a feeder, but in the mathematical model we use only integers (Strings for dict keys, to maintain JSON compatibility, and Ints for ids within the data properties). For example:
""" |> Markdown.parse

# ╔═╡ a198d7a7-241b-4f95-9a1e-21b0d05d94fd
bus_keys = keys(math["bus"])

# ╔═╡ 188dcb97-ad10-44bb-8505-af8a34884fdd
math["bus"]

# ╔═╡ 7794645c-81d7-44d2-a599-a266e42ef901
bus_ids = [bus["bus_i"] for (i, bus) in math["bus"]]

# ╔═╡ 9c4e4988-d32a-4b8a-bebc-b15f574e71e6
md"""

### Additional Metadata

- `map`
- `bus_lookup`
- `basekv`
- `baseMVA`
- `is_projected`
- `per_unit`
- `is_kron_reduced`

Two particular items classified as metadata that are key for understanding how the data model maps between the engineering and mathematical models are `bus_lookup`, which maps bus names into their new integer ids, and `map`, which is an ordered list of actions that were taken to map engineering to mathematical model, so that we can map the solutions back up to the correct components in the engineering model.

"""

# ╔═╡ 9e0fa0a9-e534-45c6-8d71-515eae33ef7d
math["bus_lookup"]

# ╔═╡ b51701bd-5ccf-4e8a-890d-cf87f92cee61
math["map"]

# ╔═╡ 105c97bf-5692-45d7-b57e-6e68f7599b85
"""
### Asset Types

For mathematical models we initially adopted the PowerModels data model, which was originally designed based on the Matpower package. We try to largely maintain this parity with PowerModels even though it is no longer a dependency, which is why there there remains some inconsistency in property names compared to the engineering model. The current components in the math model are:

- `bus`
- `load`
- `shunt`
- `gen`
- `branch`
- `transformer`
- `switch`
- `storage`

The one notable divergence is the existance of `transformer`s. In distribution models, phase unbalanced transformers are much more complex than the typical two-winding Pi-branch model commonly utilized in transmission grids.

In the PMD math model, transformers are two-winding lossless transformers that can be either wye-wye or wye-delta connected.
""" |> Markdown.parse

# ╔═╡ 01ec9412-5617-40c5-af79-756137e4973d
md"""
## `import_all`: Keeping raw DSS properties

The DSS parser included in PMD should parse all raw DSS objects and properties, but by default it will only keep around internal data fields when converting to the `ENGINEERING` or `MATHEMATICAL` data models.

To keep raw DSS properties, use the `import_all` keyword argument when parsing data:
"""

# ╔═╡ 66bb8782-86a1-4b19-8938-4feffe5c9bd1
eng_import_all = parse_file(case_file; import_all=true)

# ╔═╡ 6d6b6d03-8687-4131-af04-7b4a1230b2fa
md"""
You will notice a couple of extra data structures.

The first you may notice is "dss_options", which will list options that were set at the top-level of the DSS input
"""

# ╔═╡ 4f445224-12f7-41dc-87e1-efe23dd42625
get(eng_import_all, "dss_options", Dict())

# ╔═╡ 1a0ed93c-61d7-44b9-9eec-788c04daa5ac
md"""
Also, within each asset dictionary will be a `dss` dictionary that will contain the raw dss input about the object from which the asset was derived.
"""

# ╔═╡ 0dce4714-da1a-4241-9f87-8ce0dc5de7de
first(eng_import_all["line"]).second["dss"]

# ╔═╡ ac3cd56d-f9e1-40ed-8d36-fb4f91ce45b6
md"""
This information gets carried through to the `MATHEMATICAL` model as well...
"""

# ╔═╡ fd79914c-5609-418a-9887-7b468886d3f6
math_import_all = transform_data_model(eng_import_all)

# ╔═╡ 748f2232-1fbc-4775-955c-6646c0a6e7cc
first(math_import_all["branch"]).second["dss"]

# ╔═╡ 24e665b8-b0c5-4e26-8698-4c9e358d4b8e
md"""
# Optimization in PMD

Solving optimization problems in PowerModelsDistribution will feel very familiar to those who use PowerModels.jl for transmission grids (positive sequence representable networks).

Full optimization problems consist of a data model, a mathematical formulation, and a problem specification in which the variables, constraints and objectives are defined.

Additional details can be found in our documentation about the [mathematical problem specifications](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/math-model/) and [formulations](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/formulation-details/).
"""

# ╔═╡ 1fbf4f34-e318-47e4-8db2-cda0fdaf9c85
md"""
## Formulations

Formulations in PMD are represented by Julia Types, and have a clearly defined hierarchy, starting with our base abstact unbalanced (i.e., multiconductor) PowerModel: `AbstractUnbalancedPowerModel`.

Some useful abbreviations / acronyms in PowerModel and function names:

- `MC`/`_mc_` : multi-conductor, to differentiate from PowerModels.jl name, indicating applies to multiconductor / phase unbalanced / distribution problems.
- `U` : unbalanced
- `BF` : branch flow
- `ACP` : AC polar
- `ACR` : AC rectangular
- `IVR` : IV reectangular
- `LP` : linear program
- `SDP` : semi-definite program
- `SOC` : second-order cone
- `KCL` : Kirchoff's Current Law
- `MX` : matrix

### Non-convex Formulations

- `ACPUPowerModel` : Complex Power-Voltage space polar multiconductor form (bus injection model)
- `ACRUPowerModel` : Complex Power-Voltage space rectangular multiconductor form (bus injection model)
- `IVRUPowerModel` : Complex Current-Voltage space rectangular multiconductor form (bus injection model)

### Linear/Quadratic Formulations

- `LPUBFDiagPowerModel` / `LinDist3Flow` : Diagonal matrix formulation of DistFlow equations (unbalanced branch flow model)
- `NFAUPowerModel <: AbstractUnbalancedActivePowerModel` : Linear, Active-power-only multiconductor form (bus injection model)
- `DCPUPowerModel` : DC polar multiconductor form (bus injection model)

### Semi-definite formulations

- `SDPUBFMCPowerModel` : SDP multiconductor form (unbalanced branch flow model)
- `SDPUBFKCLMXMCPowerModel` : SDP with Matrix KCL constraint multiconductor form (unbalanced branch flow model)

### Second-Order Cone formulations

- `SOCUBFNLPMCPowerModel` : SOC-representable with non-linear ... multiconductor form (unbalanced branch flow model)
- `SOCUBFConicMCPowerModel` : SOC-representable with conic multiconductor form (unbalanced branch flow model)

A more detailed description of the type heirarchies can be found in our [documentation](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/formulations/).
"""

# ╔═╡ 9da18cf9-bded-4154-957c-fdde64e73067
"""
## Problem Specifications

Some additional helpful abbreviations for problem specifications:

- `mn` - Multinetwork, i.e., time series problem
- `uc` - unit-commitment, i.e., full load shed only, no partial shed

In PMD, there are two primary problem specifications,

- Optimal Power Flow (OPF) `solve_mc_opf`
  - There is a sub-problem for OPF called On-load Tap Changing (OLTC)
- Maximal Load Delivery (MLD) `solve_mc_mld`
  - There is also a "simple" version, but it will not work in conjunction with a switching optimization (`solve_mc_mld_simple`)
  - There is a caveat that the currently included MLD problem features continuous shedding of individual loads, which is not realistic for real-world distribution operations. While in transmission problems, one may assume some continuous shedding of loads, in real distribution grids, most loads can only be shed by using switches to isolate load blocks.

Recently, with the addition of idealized switches, we have also added a test version of a switching problem (OSW), which has variables for switch states of dispatchable switches, and an additional term in the objective to discourage state changes. This spec is experimental, but ongoing research in this area are expected to yield updates in this problem area.

We also have a debugging problem spec, `solve_mc_opf_pbs`, which will install slacks at every bus, which can be helpful in determining where the issue is in the network.

Power flow (`solve_mc_pf`) is also included, but if should be noted that this uses the same mechanism to solve as all of our optimization problems, and is therefore not efficient or quick, like a Newton-Raphson or Backwards/Forwards method for power flow solving might be.

Below is the primary example for the OPF problem:

```julia
$(@code_string build_mc_opf(instantiate_mc_model(eng, ACPUPowerModel, build_mc_opf)))
```
""" |> Markdown.parse

# ╔═╡ 45346587-3379-499c-9315-83b8b2a125cf
filter(x -> endswith(String(x), "PowerModel"), names(PowerModelsDistribution))

# ╔═╡ 56900c8e-b5fe-4b9b-b6e7-d46863025f62
md"""
# Examples

Let's start with the AC polar formulation, and solve the OPF problem using Ipopt:
"""

# ╔═╡ c9ac65e3-9439-4e1f-a921-dcaac3dc7d5f
eng_result = solve_mc_opf(eng, ACPUPowerModel, Ipopt.Optimizer)

# ╔═╡ 794ddd12-cb8e-4772-a4fe-ebb9029acd09
md"""
We have designed the `solution` dictionary to be as verbose as possible, including all variables contained in the problem automatically, in the same order and format as the input data.

This means that if an engineering data model is provided, the results will return in the same units and format as that model, unless otherwise instructed...
"""

# ╔═╡ 28380ef6-3750-4a77-8e8e-25b42e715f4f
eng_result_pu = solve_mc_opf(eng, ACPUPowerModel, Ipopt.Optimizer; make_si=false)

# ╔═╡ 9ac22ca5-52c5-4677-963e-778666238f29
eng_result_pu["solution"]["bus"]["sourcebus"]

# ╔═╡ e5a7090d-7317-4087-9506-fba5401a3864
eng_result["solution"]["bus"]["sourcebus"]

# ╔═╡ ae6cbeaf-28e1-4af1-be65-329e737d7e3a
md"""
What if `vm` and `va` are desired, but those variables are not in the model, for example, in `ACRMCPowerModel`?
"""

# ╔═╡ 94065f62-5cab-4b02-96fc-f6140067a8f8
eng_result_acr2acp = solve_mc_opf(eng, ACRUPowerModel, Ipopt.Optimizer; solution_processors=[sol_data_model!])

# ╔═╡ 458ba619-b7b8-488d-9b4c-12d12331b1d5
eng_result_acr2acp["solution"]["bus"]["sourcebus"]

# ╔═╡ 8c513960-2820-47ba-bfd4-84e8f661afae
"""
```julia
$(@code_string PowerModelsDistribution._sol_data_model_acr!(eng_result))
```
""" |> Markdown.parse

# ╔═╡ 6fde4523-a230-4da9-b14e-2f59e86cc572
md"""
It is also possible to optimize using the `MATHEMATICAL` data model directly, but it will output results in the same format as the model it is provided:
"""

# ╔═╡ c710773d-73ad-4645-b030-e09bc222cfc0
math_result = solve_mc_opf(math, ACPUPowerModel, Ipopt.Optimizer)

# ╔═╡ 9e214a86-6145-4c3d-adde-6fcf96b369a1
md"""
However, if your `MATHEMATICAL` data model contains the `map`, it is possible to manually convert the solution back into the `ENGINEERING` structure...
"""

# ╔═╡ 57cb17df-9b09-4410-8b95-e0c389d6245e
transform_solution(math_result["solution"], math)

# ╔═╡ b0da82db-7aa9-4152-a74d-e990452c2dd2
"""
# PMD Internals for Specification / Formulation Builders

A problem is formally created using `instantiate_mc_model(data, form, prob)`, and outputs a Julia Struct:

```julia
$(@code_string IM.InitializeInfrastructureModel(NFAUPowerModel, eng, PowerModelsDistribution._pmd_global_keys, pmd_it_sym))
```

The following helper functions are here to help you navigate through the mathematical model.

- `ref`
- `var`
- `con`
- `ids`

""" |> Markdown.parse

# ╔═╡ 486e9848-69b6-46ad-a6e3-7840e0008e02
pm = instantiate_mc_model(eng, NFAUPowerModel, build_mc_opf)

# ╔═╡ 86ffc716-135c-4399-986f-5f0a75fd7c65
propertynames(pm)

# ╔═╡ 572e44e7-6423-4673-90cc-7a203d0ef356
md"Using the `ref` helper function, for example, we could get all branches in the model..."

# ╔═╡ c099bcd6-bb41-4785-a390-be2b858d2d5a
math_branches = ref(pm,:branch)

# ╔═╡ 93ccc7dc-9879-4c3d-abab-530d6d2f059d
md"Or, we could get only the branch ids by using `ids`..."

# ╔═╡ f69402ca-9d39-4603-a963-6de9e6267622
branch_ids = ids(pm,:branch)

# ╔═╡ 052ad5d7-550c-42a3-9280-f83a491f1d3e
md"""
# Example: Upgrading MLD to use Load Blocks

As mentioned in the section above on Problem Specifications, the MLD problem bundled in PMD represents all loads as individually sheddable, which is not accurate to distribution feeders, where it is unlikely that loads would be sheddable by themselves. Instead, usually loads are only sheddable as a whole block, by opening switches to isolate them.

In this example I am going to get us closer to that more realistic problem by creating indicator variables for loads that apply to the whole load block, instead of variables for each load individually.

To achieve this, first we must be able to calculate the possible load blocks, which we can do with `identify_load_blocks`, which will return all sets of buses that can be isolated with switches...
"""

# ╔═╡ 939054e5-42c2-4eef-be0b-c01c2837cfe3
identify_load_blocks(math)

# ╔═╡ 39673ab1-fe6c-4047-ad65-914735245709
md"""
Then we should add the loads in each block to a `ref` for easy lookup when we are building our model...
"""

# ╔═╡ 8d6e8175-87b0-4e4b-a5c4-17515bb364d1
""
function _ref_add_load_blocks!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
	ref[:load_blocks] = Dict{Int,Set}(i => block for (i,block) in enumerate(identify_load_blocks(data)))

	load_block_map = Dict{Int,Int}()
	for (l,load) in get(data, "load", Dict())
		for (b,block) in ref[:load_blocks]
			if load["load_bus"] in block
				load_block_map[parse(Int,l)] = b
			end
		end
	end
	ref[:load_block_map] = load_block_map

	load_block_switches = Dict{Int,Vector{Int}}(b => Vector{Int}([]) for (b, block) in ref[:load_blocks])
	for (b,block) in ref[:load_blocks]
		for (s,switch) in get(data, "switch", Dict())
			if switch["f_bus"] in block || switch["t_bus"] in block
				if switch["dispatchable"] == 1 && switch["status"] == 1
					push!(load_block_switches[b], parse(Int,s))
				end
			end
		end
	end
	ref[:load_block_switches] = load_block_switches
end

# ╔═╡ b1893001-f0a1-426f-b518-8c1f9a559d69
md"""
Because of a recent upgrade to support multi-infrasture models, we now want to use `apply_pmd!` to help us apply this ref, which will help us apply things to the correct data structure and to each subnetwork, if applicable.
"""

# ╔═╡ 75377add-00a9-495a-a99f-09f70d56e705
""
function ref_add_load_blocks!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    apply_pmd!(_ref_add_load_blocks!, ref, data; apply_to_subnetworks=true)
end

# ╔═╡ 6dcdbfcf-0e9c-46f6-bc6c-016e78c88c47
md"""
We will demonstrate how to apply this `add_ref_load_blocks!` later, but in the next steps we will assume we already have these added refs avaiable to us.

Next we need to add the new indicator variables. An indicator variable is a variable z ∈ [0,1] that we can use to shed the loads. This variable gets applied to the real and reactive load power values, so that the load can be dynamically shed in the algorithm.

Because we need to shed whole blocks at a time, there should only be one indicator variable for each block.
"""

# ╔═╡ 0ce5f4ca-c54f-4177-ac40-2635d11dc8e6
"create variables for demand status by load block"
function variable_mc_load_block_indicator(pm::AbstractUnbalancedPowerModel; nw::Int=IM.nw_id_default, relax::Bool=false, report::Bool=true)
    if relax
        z_demand = var(pm, nw)[:z_demand_blocks] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :load_blocks)], base_name="$(nw)_z_demand",
            lower_bound = 0,
            upper_bound = 1,
            start = 1.0
        )
    else
        z_demand = var(pm, nw)[:z_demand_blocks] = JuMP.@variable(pm.model,
            [i in ids(pm, nw, :load_blocks)], base_name="$(nw)_z_demand",
            binary = true,
            start = 1
        )
    end

    load_block_map = ref(pm, nw, :load_block_map)

    var(pm, nw)[:z_demand] = Dict(l => z_demand[load_block_map[l]] for l in ids(pm, nw, :load))

    # expressions for pd and qd
    pd = var(pm, nw)[:pd] = Dict(i => var(pm, nw)[:z_demand][i].*ref(pm, nw, :load, i)["pd"] for i in ids(pm, nw, :load))
    qd = var(pm, nw)[:qd] = Dict(i => var(pm, nw)[:z_demand][i].*ref(pm, nw, :load, i)["qd"] for i in ids(pm, nw, :load))

    report && IM.sol_component_value(pm, pmd_it_sym, nw, :load, :status, ids(pm, nw, :load), var(pm, nw)[:z_demand])
    report && IM.sol_component_value(pm, pmd_it_sym, nw, :load, :pd, ids(pm, nw, :load), pd)
    report && IM.sol_component_value(pm, pmd_it_sym, nw, :load, :qd, ids(pm, nw, :load), qd)
end

# ╔═╡ 65072f00-fb30-4b65-bb83-e7956a245aa2
md"""
The last three lines are how the pd and qd variables get added to the solution.

Finally, we need to update the problem to use this new variable. Lets use the "simple" mld problem as a starting point.

First we need the problem definition (the builder).

Note that in this example I am using a Unbalanced Branch Flow formulation, which obviously has some different constraints in the branch section than would be used with, e.g., the NLP formulations.
"""

# ╔═╡ 29ab5be8-954e-4cca-a938-cbb6806ed410
"Multinetwork load shedding problem for Branch Flow model"
function build_mc_mld_simple_loadblock(pm::AbstractUBFModels)
	variable_mc_bus_voltage(pm)

    variable_mc_branch_power(pm)
	variable_mc_branch_current(pm)
    variable_mc_switch_power(pm)
    variable_mc_transformer_power(pm)

    variable_mc_generator_power(pm)

    variable_mc_load_block_indicator(pm; relax=true)
    variable_mc_shunt_indicator(pm; relax=true)
	variable_mc_storage_power_mi(pm; relax=true)

   	constraint_mc_model_current(pm)

    for i in ids(pm, :ref_buses)
        constraint_mc_theta_ref(pm, i)
    end

    for i in ids(pm, :gen)
        constraint_mc_generator_power(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_mc_power_balance_shed(pm, i)
    end

    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity_mi(pm, i)
        constraint_mc_storage_losses(pm, i)
        constraint_mc_storage_thermal_limit(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_mc_power_losses(pm, i)
        constraint_mc_model_voltage_magnitude_difference(pm, i)

        constraint_mc_voltage_angle_difference(pm, i)

        constraint_mc_thermal_limit_from(pm, i)
        constraint_mc_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :switch)
        constraint_mc_switch_state(pm, i)
        constraint_mc_switch_thermal_limit(pm, i)
    end

    for i in ids(pm, :transformer)
        constraint_mc_transformer_power(pm, i)
    end

    objective_mc_min_load_setpoint_delta_simple(pm)
end

# ╔═╡ 8e8c1c7d-feca-41a7-a42b-e8cbf56c8614
md"""
Next, we need a way to call this problem to solve it:
"""

# ╔═╡ a0addd1d-67b3-4417-92be-9a6253d83f4d
""
function solve_mc_mld_simple_loadblock(data::Dict{String,<:Any}, model_type::Type, solver; kwargs...)
    return solve_mc_model(data, model_type, solver, build_mc_mld_simple_loadblock; ref_extensions=[ref_add_load_blocks!], kwargs...)
end

# ╔═╡ 37201392-0ef6-463b-a2a7-85a8b06114fa
md"""
Note in particular the addition of the `ref_extensions` keyword argument, which takes a vector of function references. This is how we add our custom ref extension `ref_add_load_blocks!`
"""

# ╔═╡ 37088269-bc99-4df2-89d1-3b7183f3d11c
mld_result = solve_mc_mld_simple_loadblock(eng, LPUBFDiagPowerModel, Ipopt.Optimizer)

# ╔═╡ 6fc00d1c-1f45-4ff2-91d8-7ef8c8bbeb39
md"""
But we can see that no loads get shed in the case, because there is no contingency applied to this feeder

What if we instead apply a contingency where power delivery is disabled on one phase, what happens?
"""

# ╔═╡ b1abb0e9-23f2-4f37-a856-8b10c8712041
begin
	eng_vs_disabled = deepcopy(eng)
	eng_vs_disabled["voltage_source"]["source"]["pg_ub"] = [Inf, Inf, 0]
	eng_vs_disabled["voltage_source"]["source"]["qg_ub"] = [Inf, Inf, 0]
end

# ╔═╡ ded2de4c-6524-47e1-8982-5c21e4b6dc3c
mld_vs_disabled_result = solve_mc_mld_simple_loadblock(eng_vs_disabled, LPUBFDiagPowerModel, Ipopt.Optimizer)

# ╔═╡ b64182df-e1b2-450d-ae95-e217b0cb8f7b
md"""
Because loads are tied together, we must shed all of the load in this block, even though only one phase could not deliver power.

This is a very simplistic example, and therefore the results may not seem interesting in themselves.

Finally, I want to note that in this example, status is not == 0, even though we might expect it to be. This is because we are using the "relaxed" version of the indicator constraints, which will often be not quite zero or one, even when we might expect them to be, especially in the case of the "simple" mld problem.

To guarantee 0 or 1, which is the most realistic for distribution feeders, we should use the unrelaxed indicator variables, but this will require using a different solver that can support mixed-integer variables. In the case of the problem I created above, Juniper, using Cbc and Ipopt might be a good option, but e.g., Gurobi would be better.
"""

# ╔═╡ 25fd05e1-0f72-4bfe-bb99-bac2e25771e1
md"""
# Multinetwork Data and Problems

Next we will cover multinetwork problems, e.g. time series OPF.

PMD has a lot of tools for multinetwork problems, but really only one constraint that is inherently multinetwork, storage state.

Let's start with constructing a multinetwork data structure, and exploring it.

First, for multinetwork data to be created automatically, we need `time_series` data. If we have chosen one of the data sets above that contains `time_series`, this should have entries...
"""

# ╔═╡ 705b01cd-7024-4b92-97a0-1561139e691c
get(eng, "time_series", Dict())

# ╔═╡ 43d6516f-e25c-4a6f-bea0-31d44bd6e7f3
md"""
`time_series` is one of our "data" objects, in that it does not represent actual assets on the feeder, but represents information about one or more assets. `linecode`s are the most often encountered and most familiar data objects in feeder data.

Each `time_series` object will have "time", "values", and "replace", at a minimum, with optional "source_id", to help find the orginating object, and "offset", for which the intention if for it to add an offset to "time". "offset" is not yet supported, but datetime strings or floats in units of hours in "time" are supported.

"replace" indicates whether the values in "values" will replace the property they are assigned to, if `false`, values will be multiplied by the base value.

To apply a `time_series` object to a property, it must be specified within an asset's specification:
"""

# ╔═╡ 8bcab71a-f1b5-43b5-9d1e-020e44b7bb9f
filter(x->!isempty(x.second), Dict(type => Dict(name => obj for (name, obj) in get(eng, type, Dict()) if haskey(obj, "time_series")) for type in pmd_eng_asset_types))

# ╔═╡ 90c06b9c-d86c-47b0-89ee-e581d4fd860d
md"""
If a input data set with timeseries data has been selected then one should find objects that have their own `"time_series"` dictionary, inside of which the keys are properties to be replaced, and values are references to root-level `time_series` objects.

OpenDSS has multiple ways to specify time series data, most usually through `LoadShapes`, which are specified on `Load` objects via the `daily` or `yearly` properties most often.

By default PMD will parse the `daily` time series data, but you can specify this at parse:

```julia
parse_file(case_file; time_series="yearly")
```

If anything other than `"daily"` is chosen, it might be necessary to adjust `time_elapsed`, which will be discussed below.

If you have `time_series` data specified correctly, building a multinetwork is straightforward:
"""

# ╔═╡ 246eaa9c-a1ff-4376-868a-075ed99bdd7a
mn_eng = make_multinetwork(eng)

# ╔═╡ 60c8cd7a-5ff3-4695-9623-163a1aabb0dc
md"""
It is also possible to load from a file directly into a multinetwork data structure:

```julia
parse_file(case_file; multinetwork=true)
```

This transformation changes the root-level of the data model pretty drastically.
"""

# ╔═╡ 52c24915-9202-413f-b752-a36e0fcf4521
keys(mn_eng)

# ╔═╡ 87a96683-56aa-4103-860b-4cc91ffcfc96
md"Compared to a non-multinetwork structure..."

# ╔═╡ 69f0a240-9a95-4ff8-9b72-5fa1aabb5850
keys(eng)

# ╔═╡ f995610f-45bc-41b7-8f02-b4f20eb9a0e4
md"""
However, what is really happening here is that only some information is needed at the root-level, and some information is paired directly with subnetworks (what we can a timestep in the multinetwork structure).

At the top level, we really need `"data_model"`, `"nw"`, and `"multinetwork"`. Even `"mn_lookup"` is only useful for one of our helper functions for manually reorganizing subnetworks `sort_multinetwork!`

The subnetworks live inside `"nw"`:
"""

# ╔═╡ 0eb1175e-ba1e-401f-b4bc-09b118725dfd
mn_eng["nw"]

# ╔═╡ f9a1171b-f8f8-4593-9d5c-7bb6fd6acade
md"""
Inside `nw`, subnetworks are organized by string integers, corresponding to the "time step". This makes iterating through them consistent...
"""

# ╔═╡ a9b3517b-8cf0-4d6e-9736-2163c1d5d96d
sort([parse(Int, n) for n in keys(mn_eng["nw"])])

# ╔═╡ 9371ae0a-4df0-4b98-b827-3ed618e30289
md"""
Each subnetwork contains all of the information we should need for variables, constraints, etc. at that time step:
"""

# ╔═╡ 10024067-4741-4eb5-b524-8bc4c1c8881a
first(mn_eng["nw"]).second

# ╔═╡ fbcdadfb-f6c4-4445-a48e-028a63683637
md"""
The reason for so much duplication of data is that the vision for multinetworks was never just for time series data, but that it could be used more generally in creative ways, like pairing two topologically different networks together with custom problem specifications.

This use case means that things that you might expect to stay the same between time steps, like `conductor_ids`, `linecodes`, `settings`, and the overall topology, could be drastically different, and therefore should be replicated for each subnetwork.

This also explains the origin of the name "multinetwork", in case the standard use case made its name confusing.

As an interesting note, `make_multinetwork` will always return a multinetwork structure, even if there is no `time_series` data, with a single subnetwork with key `"0"`.

Transforming into the `MATHEMATICAL` data model from a multinetwork `ENGINEERING` data model is also the same as for single network data:
"""

# ╔═╡ 7b7fe77c-b4bb-4af1-b8bc-ed6463d3928b
mn_math = transform_data_model(mn_eng)

# ╔═╡ 00fb62a4-13de-4427-a09d-e60e0ec53903
md"""
Some of the root-level keys will be slightly different, but otherwise you will see what you are already familiar with in the single network `MATHEMATICAL` data model.

It is also possible to transform directly into a multinetwork `MATHEMATICAL` data model from a single network `ENGINEERING` data model:

```julia
mn_math = transform_data_model(eng; multinetwork=true)
```

The one major caveat with these automatic generations of multinetwork data structures is that it **must** be performed before converting to the `MATHEMATICAL` data model. This is because, since we support replacing arbitrary fields with `time_series` data, it is impossible to work out the conversions within the `time_series` objects.

If you have a `MATHEMATICAL` data model and want to convert it to a multinetwork, this is supported, but you must already have a special construction of the `time_series` object that matches the format expected by InfrastructureModels, which has its own, more general, `make_multinetwork` function.

Multinetworks have two key helper functions:

- `sort_multinetwork!`
- `set_time_elapsed!`

The first accepts a Vector of `time` values, which it will use to manually re-sort the subnetworks, and the second accepts either a vector of time deltas or a single time delta, and replaces the `time_elapsed` property within all the subnetworks.

`time_elapsed` a value in hours that indicates how long each time step duration is, which is needed for calculating storage losses.
"""

# ╔═╡ 615d8814-c7c2-4e33-9208-10174bcc62fc
set_time_elapsed!(mn_eng, 0.5)

# ╔═╡ ef87e1ac-9207-456f-aa66-3b4f6f992a58
first(mn_eng["nw"]).second["time_elapsed"]

# ╔═╡ 9e9a3c82-7d95-46c0-94c2-f82d03e7e277
"""
Solving multinetworks is not anymore difficult than single network cases, but a special problem specification must be used that is multinetwork-aware...

```julia
$(@code_string build_mn_mc_opf(instantiate_mc_model(mn_eng, ACPUPowerModel, build_mn_mc_opf; multinetwork=true)))
```
""" |> Markdown.parse

# ╔═╡ ea755f2f-0c7a-49b4-be03-c097b800fa8f
md"""
Note that the standard OPF problem loops over each subnetwork (not necessarily in order), with the keyword argument `nw=n`.

Currently the only build-in asset that truly has multinetwork constraints is storage, where you can see the `constraint_storage_state` being called with two nw ids near the bottom of the above specification.

Knowing this, solving a multinetwork OPF problem is straightforward:
"""

# ╔═╡ c5055f1e-1715-4055-9ef9-beed2cb47b48
mn_result = solve_mn_mc_opf(mn_eng, ACRUPowerModel, Ipopt.Optimizer)

# ╔═╡ 3cc160ad-9741-45d1-9bdb-33193384aac7
md"""
# Merging Solution with Data

It is possible to merge your solutions with your data structures, which will make transporting and/or visualizing data easier. This helper function from InfrastructureModels allows you to merge two *nested* dictionaries together:
"""

# ╔═╡ d2135a89-f700-4f37-b59f-f0c4836cc17a
 eng_copy = deepcopy(eng)

# ╔═╡ f8e851ba-dbcf-4ed7-8d6f-c73364cb7d3d
update_data!(eng_copy, eng_result["solution"])

# ╔═╡ 25e40b2a-0244-432b-b46e-c85a7f5d1169
first(eng_copy["bus"]).second

# ╔═╡ e950b812-9c58-46b1-844c-b15258e36fb9
begin
	math_copy = deepcopy(math)
	update_data!(math_copy, math_result["solution"])
end

# ╔═╡ 15deaa77-0489-4ad3-a5ab-31a9c3d54dfa
first(math_copy["bus"]).second

# ╔═╡ c60cb7a3-e4ff-4383-b04d-792f3245d40c
md"""
# Exporting and Importing PMD Data Structures

It is possible to export our data structures to JSON, but you may have noticed several items that are not strictly JSON compatible, like Matrix, Enum, Symbol, Inf and NaN. Because most users default to JSON.print to export data structures, we have chosen to create a data model correction helper function that will attempt to fix data structures. For straightforward cases this has shown to work well, but may be fragile in its implementation.
"""

# ╔═╡ c062b086-c379-4bda-a881-71df33447d84
begin
	io = PipeBuffer()
	JSON.print(io, eng, 2)
end

# ╔═╡ 71b8d643-381e-4666-8f8b-0acc0638ddfb
raw_from_json = JSON.parse(io)

# ╔═╡ 06beb606-e968-4e33-8aa8-cb08efe2a9ae
begin
	parsed_from_json = deepcopy(raw_from_json)
	correct_json_import!(parsed_from_json)
	parsed_from_json
end

# ╔═╡ 3c23676b-5d59-4ed3-8684-068669c53181
md"""
This can be easily achieved via `parse_file`:

```julia
parse_file(json_file)
```
"""

# ╔═╡ 1b59743f-3917-4a17-bdd4-98ad276ec443
md"""
# Experimental Network Plots with PowerModelsAnalytics

It is possible to quickly create some plots of power networks using `PowerModelsAnalytics.plot_network!`.

Originally we created the plotting functionality in PowerModelsAnalytics primarily for debugging purposes, to look for topological errors, check for errors with load shedding, etc., and had based it on Plots.jl, which is a very popular Julia plotting tool. Unfortunately, plotting graph networks with a lot of nodes is very slow, and we discovered Vega.jl, which is a interface to the Vega visualization grammar.

For the most part, simple plots can be easily achieved with `plot_network!` (best used for Pluto notebooks to produce the plot in the notebook), or `plot_network`, which will return the LightGraphs-based graph representation of the network.
"""

# ╔═╡ de24194d-11c4-4267-af07-d168d8f85052
plot_network!(eng_copy)

# ╔═╡ 4faaf5d8-d6d0-48ce-9300-e3a8c75e5a68
md"""
While plots won't be publication ready, with some knowledge of Vega, and some tweaking of the plot specifications, it should be possible to produce some nice outputs.

Under the hood, PMA uses Networkx to automatically layout the graph, but `use_coordinates=true` can be used to use any buscoords included in the data set.
"""

# ╔═╡ 19186fa1-a6f3-49da-b752-d163a85f14b3
try
	plot_network!(eng_copy; use_coordinates=true)
catch
	md"**no buscoords exist for this case_file**"
end

# ╔═╡ 76715584-9d46-4bca-8b54-bb495c5800a3
md"""
# Development

PowerModelsDistribution is subject to active, ongoing development, and is used internally by various high-profile projects, making its improvement and maintanence high priority.

If you find bugs while using PMD, we encourage you to submit bug reports on our [GitHub Issues](https://github.com/lanl-ansi/PowerModelsDistribution.jl/issues).

If you have questions about using PMD, [JuliaLang Discourse](https://discourse.julialang.org/) is a great place, which several of our developers regularly watch, particularly in the [Optimization Category](https://discourse.julialang.org/c/domain/opt/13).

We always welcome [Pull Requests](https://github.com/lanl-ansi/PowerModelsDistribution.jl/pulls) for new features and bug fixes as well.
"""

# ╔═╡ Cell order:
# ╟─4777a080-f501-11f0-13d5-d7408a561223
# ╟─a30ec1bc-2e4f-4497-868a-7b064b010b8a
# ╠═efb83906-40dc-4245-bc6a-b7c767b6e250
# ╠═1c74137d-1c4c-4726-9e62-dcee32e163b1
# ╠═85895646-435a-437a-bb1e-0f0c0ed2a465
# ╠═84482fb7-b96f-4cb0-9d0d-dee03d31dbe4
# ╟─b2993319-0c2d-414d-a86e-3e470b34e0bc
# ╟─07f71542-ee2a-41f6-ab97-8a852bf4c7bd
# ╟─3fe558b3-1222-4bdc-b126-18e7d4ede75e
# ╟─f84697c2-cb05-4b57-987e-f00e2ae39c20
# ╠═aeb4a5bf-c8d8-447c-870a-f9c9f7c21e75
# ╟─ee3fa83d-8480-4266-9c02-1f59c9803c81
# ╠═67d3c28e-a3c8-419c-89ea-ac5fa6cfa18e
# ╟─96188c03-1d47-4ce9-a3a8-6b2f629bd4db
# ╟─c6649922-5069-41ae-bf86-472f51d20387
# ╠═9e1cddb5-7a34-4122-95fb-ab4d9cbe22f9
# ╟─23231012-e964-4b7f-a102-44f7add8d251
# ╟─110ec8c3-19e7-469a-86f7-c1b702d32e7c
# ╟─b9bc6e55-052a-4900-990e-2834e1787069
# ╟─ee4bc59d-49c2-452e-84c9-60916e85d008
# ╠═d41d8592-3ecf-4245-bbe5-59320dfa746a
# ╟─def57270-e13d-4351-9773-dedd6a8e03d8
# ╠═a46e7ce7-6a6a-4238-aa1f-53a7eb4cb980
# ╟─e349cba9-a37d-4d2d-95c4-8c75488871f1
# ╠═d837c1da-6c1e-4a72-a955-3fc1f8ff013b
# ╟─7888ea50-fe69-4277-8123-67f0dee04528
# ╟─b4bce3c1-440d-4124-af38-3933189da721
# ╟─f6d6b1cb-52db-47cf-a4ed-c73062d1b4ec
# ╟─88545c6a-1d29-4159-a3dc-71e81fc0cdb2
# ╠═d72af654-08f2-423a-9eb2-29923fc3edc4
# ╟─06aa16fd-ec03-4806-8c16-6e5e9db93c23
# ╟─2fa4a333-dc26-447a-9ddf-0d20b97233c2
# ╟─1af072c6-1e55-479e-be14-6e4b4f7fe234
# ╠═ee4d2030-18fc-4cb7-b641-d002c8d9de1a
# ╟─b14722db-636d-46bc-95a5-5ab92796b742
# ╠═a5d53b72-b1ce-40cb-be9d-2f755e3df514
# ╟─2fae4366-c36f-4bc8-a766-50096be2282c
# ╟─179238e2-3f4e-4f11-b7aa-1eaf6e2280aa
# ╟─6ea6de86-caea-40af-80cd-2d2a5264adca
# ╟─741b9a2b-cf14-4d2d-a3a2-e8157d32723d
# ╠═a198d7a7-241b-4f95-9a1e-21b0d05d94fd
# ╠═188dcb97-ad10-44bb-8505-af8a34884fdd
# ╠═7794645c-81d7-44d2-a599-a266e42ef901
# ╟─9c4e4988-d32a-4b8a-bebc-b15f574e71e6
# ╠═9e0fa0a9-e534-45c6-8d71-515eae33ef7d
# ╠═b51701bd-5ccf-4e8a-890d-cf87f92cee61
# ╟─105c97bf-5692-45d7-b57e-6e68f7599b85
# ╟─01ec9412-5617-40c5-af79-756137e4973d
# ╠═66bb8782-86a1-4b19-8938-4feffe5c9bd1
# ╟─6d6b6d03-8687-4131-af04-7b4a1230b2fa
# ╠═4f445224-12f7-41dc-87e1-efe23dd42625
# ╟─1a0ed93c-61d7-44b9-9eec-788c04daa5ac
# ╠═0dce4714-da1a-4241-9f87-8ce0dc5de7de
# ╟─ac3cd56d-f9e1-40ed-8d36-fb4f91ce45b6
# ╠═fd79914c-5609-418a-9887-7b468886d3f6
# ╠═748f2232-1fbc-4775-955c-6646c0a6e7cc
# ╟─24e665b8-b0c5-4e26-8698-4c9e358d4b8e
# ╟─1fbf4f34-e318-47e4-8db2-cda0fdaf9c85
# ╟─9da18cf9-bded-4154-957c-fdde64e73067
# ╠═45346587-3379-499c-9315-83b8b2a125cf
# ╟─56900c8e-b5fe-4b9b-b6e7-d46863025f62
# ╠═c9ac65e3-9439-4e1f-a921-dcaac3dc7d5f
# ╟─794ddd12-cb8e-4772-a4fe-ebb9029acd09
# ╠═28380ef6-3750-4a77-8e8e-25b42e715f4f
# ╠═9ac22ca5-52c5-4677-963e-778666238f29
# ╠═e5a7090d-7317-4087-9506-fba5401a3864
# ╟─ae6cbeaf-28e1-4af1-be65-329e737d7e3a
# ╠═94065f62-5cab-4b02-96fc-f6140067a8f8
# ╠═458ba619-b7b8-488d-9b4c-12d12331b1d5
# ╟─8c513960-2820-47ba-bfd4-84e8f661afae
# ╟─6fde4523-a230-4da9-b14e-2f59e86cc572
# ╠═c710773d-73ad-4645-b030-e09bc222cfc0
# ╟─9e214a86-6145-4c3d-adde-6fcf96b369a1
# ╠═57cb17df-9b09-4410-8b95-e0c389d6245e
# ╟─b0da82db-7aa9-4152-a74d-e990452c2dd2
# ╠═486e9848-69b6-46ad-a6e3-7840e0008e02
# ╠═86ffc716-135c-4399-986f-5f0a75fd7c65
# ╟─572e44e7-6423-4673-90cc-7a203d0ef356
# ╟─c099bcd6-bb41-4785-a390-be2b858d2d5a
# ╟─93ccc7dc-9879-4c3d-abab-530d6d2f059d
# ╠═f69402ca-9d39-4603-a963-6de9e6267622
# ╟─052ad5d7-550c-42a3-9280-f83a491f1d3e
# ╠═939054e5-42c2-4eef-be0b-c01c2837cfe3
# ╟─39673ab1-fe6c-4047-ad65-914735245709
# ╠═8d6e8175-87b0-4e4b-a5c4-17515bb364d1
# ╟─b1893001-f0a1-426f-b518-8c1f9a559d69
# ╠═75377add-00a9-495a-a99f-09f70d56e705
# ╟─6dcdbfcf-0e9c-46f6-bc6c-016e78c88c47
# ╠═0ce5f4ca-c54f-4177-ac40-2635d11dc8e6
# ╟─65072f00-fb30-4b65-bb83-e7956a245aa2
# ╠═29ab5be8-954e-4cca-a938-cbb6806ed410
# ╟─8e8c1c7d-feca-41a7-a42b-e8cbf56c8614
# ╟─a0addd1d-67b3-4417-92be-9a6253d83f4d
# ╟─37201392-0ef6-463b-a2a7-85a8b06114fa
# ╠═37088269-bc99-4df2-89d1-3b7183f3d11c
# ╟─6fc00d1c-1f45-4ff2-91d8-7ef8c8bbeb39
# ╠═b1abb0e9-23f2-4f37-a856-8b10c8712041
# ╠═ded2de4c-6524-47e1-8982-5c21e4b6dc3c
# ╟─b64182df-e1b2-450d-ae95-e217b0cb8f7b
# ╟─25fd05e1-0f72-4bfe-bb99-bac2e25771e1
# ╠═705b01cd-7024-4b92-97a0-1561139e691c
# ╟─43d6516f-e25c-4a6f-bea0-31d44bd6e7f3
# ╠═8bcab71a-f1b5-43b5-9d1e-020e44b7bb9f
# ╟─90c06b9c-d86c-47b0-89ee-e581d4fd860d
# ╠═246eaa9c-a1ff-4376-868a-075ed99bdd7a
# ╟─60c8cd7a-5ff3-4695-9623-163a1aabb0dc
# ╠═52c24915-9202-413f-b752-a36e0fcf4521
# ╟─87a96683-56aa-4103-860b-4cc91ffcfc96
# ╠═69f0a240-9a95-4ff8-9b72-5fa1aabb5850
# ╟─f995610f-45bc-41b7-8f02-b4f20eb9a0e4
# ╠═0eb1175e-ba1e-401f-b4bc-09b118725dfd
# ╟─f9a1171b-f8f8-4593-9d5c-7bb6fd6acade
# ╠═a9b3517b-8cf0-4d6e-9736-2163c1d5d96d
# ╟─9371ae0a-4df0-4b98-b827-3ed618e30289
# ╠═10024067-4741-4eb5-b524-8bc4c1c8881a
# ╟─fbcdadfb-f6c4-4445-a48e-028a63683637
# ╠═7b7fe77c-b4bb-4af1-b8bc-ed6463d3928b
# ╟─00fb62a4-13de-4427-a09d-e60e0ec53903
# ╠═615d8814-c7c2-4e33-9208-10174bcc62fc
# ╠═ef87e1ac-9207-456f-aa66-3b4f6f992a58
# ╟─9e9a3c82-7d95-46c0-94c2-f82d03e7e277
# ╟─ea755f2f-0c7a-49b4-be03-c097b800fa8f
# ╠═c5055f1e-1715-4055-9ef9-beed2cb47b48
# ╟─3cc160ad-9741-45d1-9bdb-33193384aac7
# ╠═d2135a89-f700-4f37-b59f-f0c4836cc17a
# ╠═f8e851ba-dbcf-4ed7-8d6f-c73364cb7d3d
# ╠═25e40b2a-0244-432b-b46e-c85a7f5d1169
# ╠═e950b812-9c58-46b1-844c-b15258e36fb9
# ╠═15deaa77-0489-4ad3-a5ab-31a9c3d54dfa
# ╠═c60cb7a3-e4ff-4383-b04d-792f3245d40c
# ╠═c062b086-c379-4bda-a881-71df33447d84
# ╠═71b8d643-381e-4666-8f8b-0acc0638ddfb
# ╠═06beb606-e968-4e33-8aa8-cb08efe2a9ae
# ╠═3c23676b-5d59-4ed3-8684-068669c53181
# ╟─1b59743f-3917-4a17-bdd4-98ad276ec443
# ╠═c4627de3-d3df-4b92-a969-464cd1d2cd96
# ╠═de24194d-11c4-4267-af07-d168d8f85052
# ╠═4faaf5d8-d6d0-48ce-9300-e3a8c75e5a68
# ╠═19186fa1-a6f3-49da-b752-d163a85f14b3
# ╠═76715584-9d46-4bca-8b54-bb495c5800a3
