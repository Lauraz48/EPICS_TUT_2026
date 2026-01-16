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

# ╔═╡ 43347c40-6c9d-4075-b5c1-fea3c8d31f32
begin
	using OpenDSSDirect
	const ODSS = OpenDSSDirect
end

# ╔═╡ b1c1c6ea-7eff-4037-b9d7-7398960b1a5a
using DataFrames, Plots, CSV, PlutoUI, Logging

# ╔═╡ 1f8edf46-f9d0-4239-9f1f-09992563b8b1
using PowerModelsDistribution

# ╔═╡ 22902010-217a-4c90-a55f-31b60f61d801
using Ipopt

# ╔═╡ 0751e81a-7504-4ab9-8427-1fb2d42b1b55
md"""
# 0. Power Flow Analysis
"""

# ╔═╡ 54578622-a2f0-4bc7-8485-c286c7bee532
md"""
## 0.1 OpenDSSDirect for PF
This notebook provides introduction to OpenDSSDirect and its usage in power flow analysis.
"""

# ╔═╡ 88c5dba7-0953-4c34-858a-123463c8667b
md"""
`OpenDSSDirect.jl` is a `Julia` package that implements a native, "direct" library interface to `OpenDSS`, an open-source distribution system simulator.
The interface can be faster than the traditional COM interface and supports multiple platforms. Currently, Windows, Linux, and macOS are supported on both ARM and x86 processors. 
"""

# ╔═╡ dc548c7b-1ae3-4a5b-b630-d93abee04041
md"""
### 0.1.1 Package Installation
"""

# ╔═╡ bba1a4a9-b577-4447-88c0-6f20d34d1aec
md"""
The package can be installed in Julia via the package manager:
```julia
import Pkg
Pkg.add("OpenDSSDirect")
```
"""

# ╔═╡ 490eb3ad-42e6-48cc-823e-5507cd8c54cb
md"""
Or, within the Julia REPL:
```Julia
]add OpenDSSDirect
```
"""

# ╔═╡ c0305af1-bb18-4ac0-bb41-0477673f1ef5
md"""
To use it in the notebook:
"""

# ╔═╡ 5b1c2d99-fb70-44c3-b76a-6984bd2f3f3b
md"""
Other packages to be used in this notebook:
"""

# ╔═╡ 23fe1799-9923-41f2-b63d-bae9a55bed18
# Use `using` instead of `import`, keep it consistent

# namespacing
# **using**: load a library into the session, plot() directly [recommend; use one in notebook, do using for this tutorial]
# import: Plots.plot()

# if namespace conflict happens, have to distinguish e.g., Plots.plot()
# for large projects, proper coding

# ╔═╡ 80fba6ba-7599-445f-bb66-10a711a7669b
plotly()

# ╔═╡ 9ce1b73f-0423-4380-9208-1d5a86f5f098
md"""
Note:
Use `using` to load a library into the session. This allows calling functions directly (e.g., plot()).

Using `import` keeps functions namespaced (e.g., Plots.plot()), which is useful when avoiding name conflicts or for proper reference in large projects.

"""

# ╔═╡ c020e96b-8ebe-4762-a26b-bfef7c5ee3eb
md"""
### 0.1.2 Run a Power Flow
"""

# ╔═╡ a40d0ac9-0f36-41d7-aec7-4cb105b8eb13
md"""
#### Load the dss network
We first load the distribution network data from the dss files.
"""

# ╔═╡ 2c03e08e-1c1c-449a-b129-85584c2f20bd
case_path = "../data/LV20_26bus_Fr_Copy_2"

# ╔═╡ 62256586-7b60-4014-ba5a-f3ee30d0cab9
cd(case_path)

# ╔═╡ cca88fe7-4f20-4bf2-8382-71ceb044cb21
case_file = "Master.dss"

# ╔═╡ 305a6048-8ccb-49db-b4c9-ad5cc3ddac69
begin
	dss_content = open(case_file, "r") do f
		join(readlines(f), "\n")
	end

	importing_data_md = """
```dss
$(dss_content)
```
		
"""
	importing_data_md |> Markdown.parse
	
end

# ╔═╡ 867fdb7f-e014-488a-bde8-e56a4b14d3af
md"""
You can have a look at the dss files in VSCode. You can install the OpenDSS syntax plugin (OpenDSS script support by tshort) through "Extensions". 
"""

# ╔═╡ fe7ef10d-473b-4b1d-8fe3-612aac398b9d
md"""
For students' better understand of the file components -- 
**Visualisation of the network? (e.g., IEEE13)**
(plot the graph, avoiding overlaps of the buses/branches, e.g., graph.jl
"""

# ╔═╡ a2186e44-c58c-4645-9014-a91702d0f6fb
md"""
#### Solve in snapshot mode
"""

# ╔═╡ dc2cb667-0a21-4ab4-a40c-11891c7ab76a
md"""
The `dss` function is the key function to call to pass commands to OpenDSS. We call the dss function with a sequence of commands to 1) clear the memory, 2) read a case file from disc, 3) solve the power flow. 

We run the set up twice to avoid edge cases in startup behavior. Often the first OpenDSS run of a session does not output correct results. 
"""

# ╔═╡ 94d10046-c33a-4907-bcd4-b3da3c46cbc3
ODSS.dss("""
		 clear
		 compile $case_file
		 set tolerance=0.00000001
		 solve
		 """)

# ╔═╡ ea816cb5-4128-4054-a6d5-30f7e4127264
ODSS.dss("""
		 clear
		 compile $case_file
		 set tolerance=0.00000001
		 solve
		 """)

# ╔═╡ caf88250-c0b5-46c6-b22a-27dab8f65919
md"""
Use [`summary`](https://opendss.epri.com/Executive2.html) to return a power flow summary of the most recent solution in the global result string.
"""

# ╔═╡ ace5a001-5f16-4f0e-bfab-59df1a56d16b
ODSS.dss("summary")

# ╔═╡ 1d9dce10-efaf-430e-9f26-7678a5e06544
md"""
### 0.1.3 Inspect the solution
The power flow for the circuit now has been solved. Now we visualise the voltage profile across buses with respect to the distance from the source, using the [methods](https://dss-extensions.org/OpenDSSDirect.jl/stable/) `OpenDSSDirect.Circuit.AllBusDistances`, which returns distance from each bus to parent EnergyMeter
and `OpenDSSDirect.Circuit.AllBusNames`, which returns the array of strings containing names of all buses in circuit.
"""

# ╔═╡ 3aa870e0-fffb-4983-9ee6-66660da0a2ee
begin
	busdistances = ODSS.Circuit.AllBusDistances()
	busnames = ODSS.Circuit.AllBusNames()
	busdistancesdf = DataFrame(Bus=busnames, busdistances=busdistances)
	sort!(busdistancesdf, [:busdistances])
end

# ╔═╡ 470a3121-e002-4425-8f29-a97dd5636abd
md"""
We can easily find the bus name and the corresponding distance, e.g.,
```Julia
busdistancesdf[busdistancesdf.Bus .== "b1699", :busdistances]
```
"""

# ╔═╡ adc2490f-bd41-4d62-94e3-5326a3b0457d
CSV.write("budistances.csv", busdistancesdf)

# ╔═╡ 01dff246-0b36-487e-a6b1-d1aae88d4b4a
md"""
We obtain the voltage results via the command [`export voltages`](https://opendss.epri.com/Export.html).
This gives voltages to ground by bus/node. 
"""

# ╔═╡ 49a385dd-84ed-46b3-8331-afc4f1506f24
ODSS.dss("""
		 export voltages
		 """)

# ╔═╡ 036d1ad7-775c-464b-b2f4-3bf60d615c04
voltages_file = "lv20_26bus_EXP_VOLTAGES.csv"

# ╔═╡ 8b1d424c-6aac-480f-a1dc-7f7df3becb22
md"""
We read the CSV into a DataFrame, and can now inspect the voltage results:
"""

# ╔═╡ 7816afd1-d591-4f1d-aedc-c5b13cfd6b99
begin
	voltages_df = CSV.read(voltages_file, DataFrame)
	voltages_df[!,:Bus] = lowercase.(voltages_df[!,:Bus])
	voltages_df
end

# ╔═╡ adb4306c-154c-428e-906a-223a66e43817
md"""
Note that OpenDSS only exports the phase-to-ground voltages, not the ph-to-neutral voltages. To derive the phase-to-neutral voltages, we need to calculate them. We store the phase-to-neutral voltage for each bus into the DataFrame as well.
"""

# ╔═╡ 270e64be-4d3a-4205-9a2c-98d93fb63e59
begin   
	∠(x) = cis(deg2rad(x))
	vpn(pm,pa,nm,na) = hypot(pm.*∠(pa) - nm.*∠(na))  # method 1
	voltages_df[!,:Van] = vpn.(voltages_df[!,Symbol(" Magnitude1")], voltages_df[!,Symbol(" Angle1")], voltages_df[!,Symbol(" Magnitude4")], voltages_df[!,Symbol(" Angle4")])
	voltages_df[!,:Vbn] = vpn.(voltages_df[!,Symbol(" Magnitude2")], voltages_df[!,Symbol(" Angle2")], voltages_df[!,Symbol(" Magnitude4")], voltages_df[!,Symbol(" Angle4")])
	voltages_df[!,:Vcn] = vpn.(voltages_df[!,Symbol(" Magnitude3")], voltages_df[!,Symbol(" Angle3")], voltages_df[!,Symbol(" Magnitude4")], voltages_df[!,Symbol(" Angle4")])
end

# ╔═╡ 67b4308e-ce3d-4c12-b305-c5980165f804
md"""
We now add the bus distance to the elements.
"""

# ╔═╡ dafb08e4-8a9f-4912-b153-bd999c7844c8
begin
	voltages_df_1 = innerjoin(voltages_df, busdistancesdf, on=:Bus)
	voltages_df_1 = voltages_df_1[2:end, :]  # exclude the first bus (xfmr primary)
	sort!(voltages_df_1,[:busdistances])
end

# ╔═╡ 65d98000-1831-4885-a4b1-e4ba85df2021
md"""
#### plot voltage profiles wrt bus distances
We can now plot the phase-to-ground voltages by distance from the distribution transformer.
"""

# ╔═╡ 5b98d946-b327-4759-a73d-285e2e61dc08
begin
	scatter(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude1")], label="phase a", widen=true, size=(600,300))
	scatter!(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude2")], label="phase b")
	scatter!(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude3")], label="phase c")
	# plot([0;1], [1;1])
	xlabel!("Distance from distribution transformer (km)")
	ylabel!("Voltage phase to ground (V)")
end

# ╔═╡ 16573d92-a5b9-4b2a-a1c3-7d4d6df108e8
md"""
Voltages are best interpreted in a relative sense, in the context of statutory limits. In distribution networks, we generally accept 10% voltage rise or drop relative to the regulatory defined voltage of 230 V.
"""

# ╔═╡ a7875c60-06a2-4f3e-aad2-0ac10c1b2f8e
begin
	scatter(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude1")], label="phase a", widen=true, size=(600,300))
	scatter!(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude2")], label="phase b")
	scatter!(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude3")], label="phase c")
	plot!([0; 0.2], [253; 253], label = "1.1 pu voltage limit")
	plot!([0; 0.2], [207; 207], label = "0.9 pu voltage limit")
	xlabel!("Distance from distribution transformer (km)")
	ylabel!("Voltage phase to ground (V)")
end

# ╔═╡ c6269e6e-ee12-4881-9425-7419e6bc2333
md"""
We can also plot the phase-to-neutral voltages. 
"""

# ╔═╡ 58671576-8728-4e48-871c-148b732102b1
begin
	scatter(voltages_df_1.busdistances, voltages_df_1.Van, label="phase a", widen=true, size=(600,300))
	scatter!(voltages_df_1.busdistances, voltages_df_1.Vbn, label="phase b")
	scatter!(voltages_df_1.busdistances, voltages_df_1.Vcn, label="phase c")
	xlabel!("Distance from distribution transformer (km)")
	ylabel!("Voltage phase-to-neutral (V)")
	xlims!(0, 0.2)
	ylims!(245, 255)
end

# ╔═╡ 16881d47-3e90-4298-95f5-22690ac1195e
begin
	scatter(voltages_df_1.busdistances, voltages_df_1[!,Symbol(" Magnitude4")], label="neutral", widen=true, size=(600,300))
	xlabel!("Distance from distribution transformer (km)")
	ylabel!("Voltage neutral-to-ground (V)")
	xlims!(0, 0.2)
	ylims!(0, 20)
end

# ╔═╡ 879f1fb1-a816-4c20-b58f-9541470745f2
md"""
For better visualisation with bus-line connections:
"""

# ╔═╡ 5cfe9a47-a3a9-4fe2-b130-a5e599791b0a
function plot_voltage_distance_busconnection()
	local p = plot(size=(600,300), xlims=[-Inf,0.2], ylabel=("Voltage Magnitude (V)"), widen=true)
	local pn =plot(size=(600,150), xlims=[-Inf,0.2], xlabel=("Distance from source (km)"), ylabel=("Neutral (V)"), widen=true)
	ylims!(p, (248,250.1))
	ylims!(pn, (0, 10))

	local line_nr = ODSS.Lines.First()
	local vlims = []
	while line_nr > 0
		local voltage = [[],[],[],[]]
		local dist =[]
		local buses =[ODSS.Lines.Bus1(), ODSS.Lines.Bus2()]
		for b in buses
			ODSS.Circuit.SetActiveBus(b)
			for i in 1:4
				append!(voltage[i], hypot.(ODSS.Bus.Voltages())[i])
			end
			append!(dist, ODSS.Bus.Distance())
		end
		plot!(p, dist, voltage[1], linecolor=:blue, label=false)
		plot!(p, dist, voltage[2], linecolor=:purple, label=false)
		plot!(p, dist, voltage[3], linecolor=:green, label=false)
		plot!(pn, dist, voltage[4], linecolor=:brown, label=false)
		for i in 1:3
		    append!(vlims, voltage[i])
		end
		line_nr = ODSS.Lines.Next()
	end

	# Load buses
	local load_nr = ODSS.Loads.First()
	local voltage= [[],[],[],[]]
	local dist = []
	while load_nr > 0
		local name = ODSS.Loads.Name()
		ODSS.Circuit.SetActiveElement("Load.$name")
		local bus = ODSS.Properties.Value("bus1")
		ODSS.Circuit.SetActiveBus(bus)
		for i in 1:4
			append!(voltage[i], hypot.(ODSS.Bus.Voltages())[i])
		end
		append!(dist, ODSS.Bus.Distance())
		load_nr = ODSS.Loads.Next()
	end
	local labels = ["Load Buses", false, false]
	for i in eachindex(labels)
		scatter!(p, dist, voltage[i], label=labels[i], color=:red)
	end
	plot!(p, legend=true)
	scatter!(pn, dist, voltage[4], label=false, color=:red)


	# Combine plots
	l = Plots.@layout [a
					  b{0.5h}]
	local pt = plot(p, pn, layout=l, yguidefontvalign = :top, size=(600,450))
	pt
end

# ╔═╡ 3a36685e-d91f-4bba-b208-c1ae1df69a73
p = plot_voltage_distance_busconnection()

# ╔═╡ 4890afa2-8ccf-456e-9d77-610047f1ee43
md"""
## 0.2 PowerModelsDistribution for PF
"""

# ╔═╡ dbec4c8b-4819-4943-aab7-10a858560003
md"""
Besides OpenDSSDirect, power flow can also be solved using `PowerModelsDistribution`.
This section shows two ways and compares the result agains that from the previous section.
"""

# ╔═╡ 0dba5627-323a-4fd3-9967-5408d860dd86
md"""
### 0.2.1 Native power flow solver
"""

# ╔═╡ a76c642e-6159-4698-9f6e-256691e2ac48
md"""
PowerModelsDistribution.jl (PMD) uses a fixed point iteration current injection method to solve power flow, similar to OpenDSS built-in solver.
Please refer to the [paper](https://arxiv.org/abs/2305.04405) for detailed formulation.
"""

# ╔═╡ 980c8cfd-5be1-49ed-97a2-3add19854640
md"""
We construct the `ENGINEERING DATA MODEL` first.
"""

# ╔═╡ 98336b14-893a-4a57-91ab-94f338dbcf61
data_eng = parse_file(case_file, transformations=[transform_loops!])  # for EN cases

# ╔═╡ 3355ae3f-0b8c-4156-af55-4f1856744621


# ╔═╡ b7cde3b8-db53-472e-bc52-0457b12236c7
md"""
Then transform it to MATHEMATICAL model using `transform_data_model`.
"""

# ╔═╡ 864cec2d-7c3d-4fc0-a764-20608953a2f7
data_math = transform_data_model(data_eng, kron_reduce=false, phase_project=false)

# ╔═╡ fab5b940-a062-4907-b4eb-7cce30581d95
md"""
Extract the base voltage for the buses in the network for later use.
"""

# ╔═╡ b84ec704-59ab-4443-b8cf-97f83eb59f28
vbase = Dict(id=>data_math["bus"]["$idx"]["vbase"]*data_math["settings"]["voltage_scale_factor"] for (id, idx) in data_math["bus_lookup"])

# ╔═╡ 5a10c799-a603-49e3-9610-f9290590bd41
md"""
Get the result for the native power flow using `compute_mc_pf`. Note that the result is in mathematical format.
"""

# ╔═╡ a7a36d22-e6d9-4a96-ae94-bfc50e8d42ef
res_pmd_math = compute_mc_pf(data_math; explicit_neutral=true, max_iter=100)

# ╔═╡ 7aa0aa07-25ca-470e-87b5-957ec95b45f9
md"""
Then we transform the solution to engineering format using [`transform_solution`](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/reference/data_models.html#PowerModelsDistribution.transform_solution)
"""

# ╔═╡ 6986fd27-7da6-4cce-9604-42fa5f717de6
res_pmd_eng = transform_solution(res_pmd_math["solution"], data_math, make_si=true)

# ╔═╡ 22cb8b8a-f511-4996-939b-4b88f8d1d38c
res_pmd_eng["bus"]

# ╔═╡ b075a56b-a22c-4465-b6d0-422342a91acf
md"""
Create a dictionary for the result from the dss voltage export.
"""

# ╔═╡ 90c84c45-8c06-4e54-a674-dd596d66cf44
function dss_voltage_csv_to_res_dict(csvfile::AbstractString)
	df = CSV.read(csvfile, DataFrame)
	rename!(df, Dict(n => strip(String(n)) for n in names(df)))
	res_bus = Dict{String, Any}()
	for r in eachrow(df)
		busid = lowercase(String(r.Bus))

		vm = Dict{String, Float64}()
		va = Dict{String, Float64}()
		for k in 1:4
			node = r[Symbol("Node$k")]
			if !ismissing(node) && node != 0
				mag = r[Symbol("Magnitude$k")]
				ang = r[Symbol("Angle$k")]

				vm[string(Int(node))] = Float64(mag)
				va[string(Int(node))] = Float64(ang)
			end
		end
		res_bus[busid] = Dict("va" => va, "vm" => vm)
	end
	return Dict("bus" => res_bus)
end
				

# ╔═╡ c873584e-9a93-436a-8868-59fb71db560d
res_dss = dss_voltage_csv_to_res_dict("lv20_26bus_EXP_VOLTAGES.csv")

# ╔═╡ f7f561d7-51fc-451a-a3a3-5cc4955da655
res_dss["bus"]

# ╔═╡ c76c7b5e-e31f-4dc9-addc-3b9156354678
md"""
We define a function to compare OpenDSS bus voltages (vm, va) against PMD bus voltages,
supporting PMD results in the polar and rectangular (Cartesian) forms:
  - polar: vm (voltage magnitude), va (voltage angle)
  - rectangular: vr (voltage real component), vi (voltage imaginary component)
We returns the maximum complex-voltage error in pu across all matched buses/terminals.

"""

# ╔═╡ 4fed0344-f8b2-4991-ad34-f20da38d3746
function compare_res_dss_pmd(res_dss::Dict{String,<:Any}, res_pmd_eng::Dict{String,<:Any}, data_eng::Dict{String,<:Any}, vbase::Dict{String,<:Any}; verbose::Bool=true, v_err_tol::Real=1E-6)
	max_v_err_pu = 0.0

	buses = intersect(keys(res_dss["bus"]), keys(res_pmd_eng["bus"]))

	for id in buses
		dss_bus = res_dss["bus"][id]
		pmd_bus = res_pmd_eng["bus"][id]

		terminals = data_eng["bus"][id]["terminals"]
		ts = filter(x->haskey(dss_bus["vm"], string(x)), terminals)

		# -------- DSS: vm/va
		v_dss = [dss_bus["vm"]["$t"]*exp(im*deg2rad(dss_bus["va"]["$t"])) for t in ts]

		# -------- PMD: either (vm/va) or (vr/vi)
		# v_pmd = [pmd_bus["vm"][idx]*exp(im*deg2rad(pmd_bus["va"][idx]))*data_eng["settings"]["voltage_scale_factor"] for (idx, t) in enumerate(ts)]
		if haskey(pmd_bus, "vm") && haskey(pmd_bus, "va")
			v_pmd = [pmd_bus["vm"][idx]*exp(im*deg2rad(pmd_bus["va"][idx]))*data_eng["settings"]["voltage_scale_factor"] for (idx, _) in enumerate(ts)]
		elseif haskey(pmd_bus, "vr") && haskey(pmd_bus, "vi")
			v_pmd = [(pmd_bus["vr"][idx] + im * pmd_bus["vi"][idx])*data_eng["settings"]["voltage_scale_factor"] for (idx, _) in enumerate(ts)]
		else
			@warn "Bus $id: PMD bus does not contain (vm,va) or (vr,vi). Skipping."
			continue
		end
		
		v_dss_pu = v_dss/vbase[id]
		v_pmd_pu = v_pmd/vbase[id]

		N = length(v_dss)
		labels = string.(ts)

		for i in eachindex(v_pmd_pu)
			v_err_pu = abs.(v_dss_pu[i] - v_pmd_pu[i]); 
			max_v_err_pu = max(max_v_err_pu, v_err_pu)

			if v_err_pu > v_err_tol && verbose
				println("terminal $id.$(labels[i])")
				println("\t  |U| dss: $(abs(v_dss_pu[i]))")
				println("\t  |U| pmd: $(abs(v_pmd_pu[i]))")
				println("\t   ∠U dss: $(angle(v_dss_pu[i]))")
				println("\t   ∠U pmd: $(angle(v_pmd_pu[i]))")
			end
		end
	end

	return max_v_err_pu
end

# ╔═╡ f62915be-8564-4107-a8a3-28e3547c4ff1
md"""
Get the maximum error.
"""

# ╔═╡ 9a813e6f-f58f-4835-acc5-a3f68c62256d
v_max_err_pu = compare_res_dss_pmd(res_dss, res_pmd_eng, data_eng, vbase, verbose=true)

# ╔═╡ 1fbcd1ef-3d7b-4e5b-84c8-ae20523c02ba


# ╔═╡ e116d21b-6f97-4b72-9d4c-e4ef7ae1201c
res_pmd_eng["bus"]["b389"]

# ╔═╡ bfa1187b-6ebd-44b3-a38e-235970da28b9
res_dss["bus"]["b389"]

# ╔═╡ 169b34f6-c357-4fa8-92a5-058adc514ed9
md"""
### 0.2.2 Using Ipopt as a nonlinear equation solver
"""

# ╔═╡ 295e4a52-4335-48cf-b722-9eca908648c7
md"""
In this case we pursue separation of model and algorithm. We construct the system of equations using JuMP that encapsulates the physics, the network limits and the behavior of loads/generators. JuMP hands over the model to Ipopt, which is a solver that can handle nonlinear systems of equtions. Note that Ipopt is generally used as an optimisation solver (i.e. there are degrees of freedom, we pursue mininisation or maximisation of some objective function, there may be bounds on the variables), but we can also use it as a solver for simulation problems (square system of equations). 
"""

# ╔═╡ 6b0a0764-6fce-481d-83b1-a4e94a5f16eb
md"""
Choose the formulation to test:
"""

# ╔═╡ 51ca3789-f6ee-4ba3-8895-d4c0ea47feb5
@bind formulation Select([IVRENPowerModel, IVRReducedENPowerModel, IVRQuadraticENPowerModel, IVRReducedQuadraticENPowerModel])

# ╔═╡ 8778e425-c7c3-43ab-acd6-b3e2176731c6
formulation

# ╔═╡ ce66d754-379c-4fc4-a95f-9a8c85691047
# formulations = [IVRENPowerModel, IVRReducedENPowerModel, IVRQuadraticENPowerModel, IVRReducedQuadraticENPowerModel] # ACRENPowerModel

# ╔═╡ c2da2c1c-b0ab-46f1-a386-303443a11a5e
md"""
Deep copy the engineering model, remove bounds, and convert it to mathematical model.
"""

# ╔═╡ 3d76d57a-8e56-4453-a80e-d2e28da599b4
data_eng_2 = deepcopy(data_eng)

# ╔═╡ 75e68068-8796-4745-be38-a901a91a47a7
md"""
We are trying to solver a power flow, in which there are no bounds, so we remove the bounds from the data we loaded. 
"""

# ╔═╡ 18fa9315-7fa7-4b43-a450-c7806a4c9f97
remove_all_bounds!(data_eng_2)

# ╔═╡ e7fa3660-3d1f-4ace-b9f4-c7a86c2044ca
data_math_2 = transform_data_model(data_eng_2, kron_reduce=false, phase_project=false)

# ╔═╡ 6c3168db-c972-456c-b22a-2efa17f131ef
md"""
We add starting values for the voltages on all buses. Respecting the phase rotation order and the 120 degrees phase angle separation is crucial. 
"""

# ╔═╡ 17f8a3c3-0ac9-4ebd-84e5-408574f4569d
add_start_vrvi!(data_math_2)

# ╔═╡ 11bea3f9-9066-45db-afba-f7b501c91ab0
md"""
Instantiate the model of choice.
"""

# ╔═╡ d9b96204-387a-44ec-8a2a-52128e38f9de
pm = instantiate_mc_model(data_math_2, formulation, build_mc_opf)

# ╔═╡ cca35b03-4f76-4e28-83d3-ed043522bfdb
md"""
Set up the solver.
"""

# ╔═╡ cff56dc3-f2ce-4da5-8e28-b9dc0e557c97
ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer)

# ╔═╡ fa3c626e-4c54-42f4-b69a-87233462cb98
md"""
Solve the model and get the result.
"""

# ╔═╡ 455b4b49-39f9-4de8-b3a4-eb4b56967f62
result = optimize_model!(pm, optimizer=ipopt_solver)

# ╔═╡ 24d9c062-c0bd-4916-8c18-9f65bba676c0
md"""
Transform the solution to engineering.
"""

# ╔═╡ 61037f62-00e5-4747-ab99-48e8f4d83382
res_pmd_ipopt = transform_solution(result["solution"], data_math_2, make_si=true)

# ╔═╡ b2cf24cb-fd6a-424c-98b4-5d41119685d8
md"""
Calculate the maximum voltage error w.r.t DSS model.
"""

# ╔═╡ 90e83716-2170-46a7-bd8e-f1b0fd64fe2f
v_max_err_pu_2 = compare_res_dss_pmd(res_dss, res_pmd_ipopt, data_eng_2, vbase, verbose=true)

# ╔═╡ 652beae9-71b8-4103-86dc-87c0b133f3de
md"""
Result comparison of the three methods above:
"""

# ╔═╡ 2429d7b9-057d-4202-b5ca-09b699036573
begin
	v_complex_dss(dss_bus::Dict, t::Int) =
	    dss_bus["vm"][string(t)] * exp(im * deg2rad(dss_bus["va"][string(t)]))
	
	function v_complex_pmd(pmd_bus::Dict, idx::Int)
	    if haskey(pmd_bus, "vm") && haskey(pmd_bus, "va")
	        return pmd_bus["vm"][idx] * exp(im * deg2rad(pmd_bus["va"][idx]))
	    elseif haskey(pmd_bus, "vr") && haskey(pmd_bus, "vi")
	        return pmd_bus["vr"][idx] + im * pmd_bus["vi"][idx]
	    else
	        return nothing
	    end
	end
end

# ╔═╡ dd3e87a7-ba6d-44c9-9733-46f922daf56b
function voltage_comparison_table(
    res_dss::Dict{String,<:Any},
    res_pmd_native::Dict{String,<:Any}, 
    res_pmd_ipopt::Dict{String,<:Any},  
    data_eng::Dict{String,<:Any},
    vbase::Dict{String,<:Any};
    include_angle_deg::Bool=true
	)
    buses = intersect(keys(res_dss["bus"]),
                      intersect(keys(res_pmd_native["bus"]), 		keys(res_pmd_ipopt["bus"])))

    vsf = get(get(data_eng, "settings", Dict{String,Any}()), "voltage_scale_factor", 1.0)

    rows = Vector{NamedTuple}()

    for id in sort(collect(buses))
        dss_bus = res_dss["bus"][id]
        nat_bus = res_pmd_native["bus"][id]
        ipt_bus = res_pmd_ipopt["bus"][id]

        terminals = data_eng["bus"][id]["terminals"]
        ts = filter(t -> haskey(dss_bus["vm"], string(t)), terminals)

        vb = vbase[id]

        for (idx, t) in enumerate(ts)
            # DSS (reference)
            v_dss_pu = v_complex_dss(dss_bus, t) / vb

            # PMD native PF
            v_nat = v_complex_pmd(nat_bus, idx)
            v_nat_pu = v_nat === nothing ? nothing : (v_nat * vsf) / vb

            # PMD OPF Ipopt
            v_ipt = v_complex_pmd(ipt_bus, idx)
            v_ipt_pu = v_ipt === nothing ? nothing : (v_ipt * vsf) / vb

            # Errors vs DSS
            err_nat = v_nat_pu === nothing ? missing : abs(v_dss_pu - v_nat_pu)
            err_ipt = v_ipt_pu === nothing ? missing : abs(v_dss_pu - v_ipt_pu)

            push!(rows, (
                bus = id,
                terminal = t,

                dss_vm_pu = abs(v_dss_pu),
            	dss_va = include_angle_deg ? rad2deg(angle(v_dss_pu)) : angle(v_dss_pu),

            	native_vm_pu = v_nat_pu === nothing ? missing : abs(v_nat_pu),
                native_va = v_nat_pu === nothing ? missing :
                            (include_angle_deg ? rad2deg(angle(v_nat_pu)) : angle(v_nat_pu)),

                ipt_vm_pu = v_ipt_pu === nothing ? missing : abs(v_ipt_pu),
                ipt_va = v_ipt_pu === nothing ? missing :
                         (include_angle_deg ? rad2deg(angle(v_ipt_pu)) : angle(v_ipt_pu)),

                err_native_pu = err_nat,
                err_ipopt_pu = err_ipt
            ))
        end
    end

    return DataFrame(rows)
end


# ╔═╡ 28f8105b-06e4-4e3e-9286-b85b7d3c277e
df_cmp = voltage_comparison_table(res_dss, res_pmd_eng, res_pmd_ipopt, data_eng, vbase)


# ╔═╡ 6c8788fa-7a09-4c95-bd04-8399769c2cef
df_global = DataFrame(
    Method = [
        "PMD native power flow",
        "PMD OPF-based solve (Ipopt)"
    ],
    Max_Voltage_Error_pu = [
        v_max_err_pu,
        v_max_err_pu_2
    ]
)

# ╔═╡ 5e2d1ad0-be6a-415c-9887-e1fede4effe1


# ╔═╡ 15f37365-0aee-41ba-aa27-09b8eebe0999


# ╔═╡ f8fda4db-8a8a-46b6-a44f-e92ae4db3e31
# res_pf_ipopt = solve_mc_model(data_eng_2, IVRENPowerModel, Ipopt.Optimizer, build_mc_pf)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
Logging = "56ddb016-857b-54e1-b83d-db4d58db5568"
OpenDSSDirect = "a8b11937-1041-50f2-9818-136bb7a8fb06"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PowerModelsDistribution = "d7431456-977f-11e9-2de3-97ff7677985e"

[compat]
CSV = "~0.10.15"
DataFrames = "~1.8.1"
Ipopt = "~1.13.0"
OpenDSSDirect = "~0.9.9"
Plots = "~1.41.4"
PlutoUI = "~0.7.60"
PowerModelsDistribution = "~0.16.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.6"
manifest_format = "2.0"
project_hash = "6062a8d1b8018379fe8817e1d6b0dce351c03cd8"

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

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

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

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fde3bf89aead2e723284a8ff9cdf5b551ed700e8"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.5+0"

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
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

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
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

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
version = "1.1.1+0"

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
version = "1.11.0"

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
version = "1.11.0"

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
git-tree-sha1 = "27af30de8b5445644e8ffe3bcb0d72049c089cf1"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.7.3+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "95ecf07c2eea562b5adbd0696af6db62c0f52560"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.5"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "01ba9d15e9eae375dc1eb9589df76b3572acd3f2"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.0.1+0"

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
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "f85dac9a96a01087df6e3a749840015a0ca3817d"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.17.1+0"

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
version = "1.11.0"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "b7bfd56fa66616138dfe5237da4dc13bbd83c67f"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.4.1+0"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "f305bdb91e1f3fcc687944c97f2ede40585b1bd5"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.19"

    [deps.GR.extensions]
    GRIJuliaExt = "IJulia"

    [deps.GR.weakdeps]
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "de439fbc02b9dc0e639e67d7c5bd5811ff3b6f06"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.19+1"

[[deps.GettextRuntime_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll"]
git-tree-sha1 = "45288942190db7c5f760f59c04495064eedf9340"
uuid = "b0724c58-0f36-5564-988d-3bb0596ebc4a"
version = "0.22.4+0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "6b4d2dc81736fe3980ff0e8879a9fc7c33c44ddf"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.86.2+0"

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
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "7a98c6502f4632dbe9fb1973a4244eaa3324e84d"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.13.1"

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
git-tree-sha1 = "f923f9a774fcf3f5cb761bfa43aeadd689714813"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.1+0"

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
version = "1.11.0"

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
git-tree-sha1 = "b6893345fd6658c8e475d40155789f4860ac3b21"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.4+0"

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
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aaafe88dccbd957a8d82f7d05be9b69172e0cee3"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.1+0"

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
deps = ["Format", "Ghostscript_jll", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "44f93c47f9cd6c7e431f2f2091fcba8f01cd7e8f"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.10"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"
    TectonicExt = "tectonic_jll"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"
    tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c8da7e6a91781c41a863611c7e966098d783c57a"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.4.7+0"

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
git-tree-sha1 = "3acf07f130a76f87c041cfb2ff7d7284ca67b072"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.41.2+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "f04133fe05eff1667d2054c53d59f9122383fe05"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.2+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2a7a12fc0a4e7fb773450d17975322aa77142106"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.41.2+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

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
version = "1.11.0"

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
version = "1.11.0"

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
version = "2.28.6+0"

[[deps.Measures]]
git-tree-sha1 = "b513cedd20d9c914783d8ad83d08120702bf2c77"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.3"

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
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

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
version = "0.3.27+1"

[[deps.OpenDSSDirect]]
deps = ["CEnum", "DocStringExtensions", "Downloads", "Libdl", "LinearAlgebra", "REPL", "SparseArrays", "Test"]
git-tree-sha1 = "e32118998c2255b4193823aac5acb075a4a72d78"
uuid = "a8b11937-1041-50f2-9818-136bb7a8fb06"
version = "0.9.9"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.5+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "NetworkOptions", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "1d1aaa7d449b58415f97d2839c318b70ffb525a0"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.6.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f19301ae653233bc88b1810ae908194f07f8db9d"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "39a11854f0cba27aa41efaedf43c77c5daa6be51"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.6.0+0"

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
git-tree-sha1 = "0662b083e11420952f2e62e17eddae7fc07d5997"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.57.0+0"

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
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "41031ef3a1be6f5bbbf3e8073f210556daeae5ca"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.3.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "26ca162858917496748aad52bb5d3be4d26a228a"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.4"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "063ef757a1e0e15af77bbe92be92da672793fd4e"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.41.4"

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
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.PtrArrays]]
git-tree-sha1 = "1d36ef11a9aaf1e8b74dacc6a731dd1de8fd493d"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.3.0"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "34f7e5d2861083ec7596af8b8c092531facf2192"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.8.2+2"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll"]
git-tree-sha1 = "da7adf145cce0d44e892626e647f9dcbe9cb3e10"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.8.2+1"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "9eca9fc3fe515d619ce004c83c31ffd3f85c7ccf"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.8.2+1"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "8f528b0851b5b7025032818eb5abbeb8a736f853"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.8.2+2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

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
version = "1.11.0"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

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
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

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
git-tree-sha1 = "4f96c596b8c8258cc7d3b19797854d368f243ddc"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.4"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "eee1b9ad8b29ef0d936e3ec9838c7ec089620308"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.16"

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
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "178ed29fd5b2a2cfc3bd31c13375ae925623ff36"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.8.0"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "aceda6f4e598d331548e04cc6b2124a6148138e3"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.10"

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

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

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
version = "1.11.0"

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
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

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
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "96478df35bbc2f3e1e791bc7a3d0eeee559e60e9"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.24.0+0"

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
git-tree-sha1 = "9cce64c0fdd1960b597ba7ecda2950b5ed957438"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.2+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a3ea76ee3f4facd7a64684f9af25310825ee3668"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.2+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "9c7ad99c629a44f81e7799eb05ec2746abb5d588"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.6+0"

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
git-tree-sha1 = "75e00946e43621e09d431d9b95818ee751e6b2ef"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "6.0.2+0"

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
git-tree-sha1 = "9750dc53819eba4e9a20be42349a6d3b86c7cdf8"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.6+0"

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
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c3b0e6196d50eab0c5ed34021aaa0bb463489510"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.14+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6a34e0e0960190ac2a4363a1bd003504772d631"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.61.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "371cc681c00a3ccc3fbc5c0fb91f58ba9bec1ecf"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.13.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "125eedcb0a4a0bba65b657251ce1d27c8714e9d6"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.4+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "56d643b57b188d30cccc25e331d416d3d358e557"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.13.4+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "91d05d7f4a9f67205bd6cf395e488009fe85b499"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.28.1+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "6ab498eaf50e0495f89e7a5b582816e2efb95f64"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.54+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b4d631fd51f2e9cdd93724ae25b2efc198b059b1"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.7+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e7b67590c14d487e734dcb925924c5dc43ec85f3"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "4.1.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "a1fc6507a40bf504527d0d4067d718f8e179b2b8"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.13.0+0"
"""

# ╔═╡ Cell order:
# ╟─0751e81a-7504-4ab9-8427-1fb2d42b1b55
# ╟─54578622-a2f0-4bc7-8485-c286c7bee532
# ╟─88c5dba7-0953-4c34-858a-123463c8667b
# ╟─dc548c7b-1ae3-4a5b-b630-d93abee04041
# ╟─bba1a4a9-b577-4447-88c0-6f20d34d1aec
# ╟─490eb3ad-42e6-48cc-823e-5507cd8c54cb
# ╟─c0305af1-bb18-4ac0-bb41-0477673f1ef5
# ╠═43347c40-6c9d-4075-b5c1-fea3c8d31f32
# ╟─5b1c2d99-fb70-44c3-b76a-6984bd2f3f3b
# ╠═b1c1c6ea-7eff-4037-b9d7-7398960b1a5a
# ╠═1f8edf46-f9d0-4239-9f1f-09992563b8b1
# ╠═22902010-217a-4c90-a55f-31b60f61d801
# ╟─23fe1799-9923-41f2-b63d-bae9a55bed18
# ╠═80fba6ba-7599-445f-bb66-10a711a7669b
# ╟─9ce1b73f-0423-4380-9208-1d5a86f5f098
# ╟─c020e96b-8ebe-4762-a26b-bfef7c5ee3eb
# ╠═a40d0ac9-0f36-41d7-aec7-4cb105b8eb13
# ╠═2c03e08e-1c1c-449a-b129-85584c2f20bd
# ╠═62256586-7b60-4014-ba5a-f3ee30d0cab9
# ╠═cca88fe7-4f20-4bf2-8382-71ceb044cb21
# ╟─305a6048-8ccb-49db-b4c9-ad5cc3ddac69
# ╟─867fdb7f-e014-488a-bde8-e56a4b14d3af
# ╠═fe7ef10d-473b-4b1d-8fe3-612aac398b9d
# ╟─a2186e44-c58c-4645-9014-a91702d0f6fb
# ╟─dc2cb667-0a21-4ab4-a40c-11891c7ab76a
# ╠═94d10046-c33a-4907-bcd4-b3da3c46cbc3
# ╠═ea816cb5-4128-4054-a6d5-30f7e4127264
# ╟─caf88250-c0b5-46c6-b22a-27dab8f65919
# ╠═ace5a001-5f16-4f0e-bfab-59df1a56d16b
# ╟─1d9dce10-efaf-430e-9f26-7678a5e06544
# ╠═3aa870e0-fffb-4983-9ee6-66660da0a2ee
# ╟─470a3121-e002-4425-8f29-a97dd5636abd
# ╠═adc2490f-bd41-4d62-94e3-5326a3b0457d
# ╟─01dff246-0b36-487e-a6b1-d1aae88d4b4a
# ╠═49a385dd-84ed-46b3-8331-afc4f1506f24
# ╠═036d1ad7-775c-464b-b2f4-3bf60d615c04
# ╠═8b1d424c-6aac-480f-a1dc-7f7df3becb22
# ╠═7816afd1-d591-4f1d-aedc-c5b13cfd6b99
# ╠═adb4306c-154c-428e-906a-223a66e43817
# ╠═270e64be-4d3a-4205-9a2c-98d93fb63e59
# ╟─67b4308e-ce3d-4c12-b305-c5980165f804
# ╠═dafb08e4-8a9f-4912-b153-bd999c7844c8
# ╟─65d98000-1831-4885-a4b1-e4ba85df2021
# ╟─5b98d946-b327-4759-a73d-285e2e61dc08
# ╟─16573d92-a5b9-4b2a-a1c3-7d4d6df108e8
# ╟─a7875c60-06a2-4f3e-aad2-0ac10c1b2f8e
# ╟─c6269e6e-ee12-4881-9425-7419e6bc2333
# ╠═58671576-8728-4e48-871c-148b732102b1
# ╠═16881d47-3e90-4298-95f5-22690ac1195e
# ╟─879f1fb1-a816-4c20-b58f-9541470745f2
# ╟─5cfe9a47-a3a9-4fe2-b130-a5e599791b0a
# ╠═3a36685e-d91f-4bba-b208-c1ae1df69a73
# ╟─4890afa2-8ccf-456e-9d77-610047f1ee43
# ╟─dbec4c8b-4819-4943-aab7-10a858560003
# ╟─0dba5627-323a-4fd3-9967-5408d860dd86
# ╟─a76c642e-6159-4698-9f6e-256691e2ac48
# ╟─980c8cfd-5be1-49ed-97a2-3add19854640
# ╠═98336b14-893a-4a57-91ab-94f338dbcf61
# ╠═3355ae3f-0b8c-4156-af55-4f1856744621
# ╟─b7cde3b8-db53-472e-bc52-0457b12236c7
# ╠═864cec2d-7c3d-4fc0-a764-20608953a2f7
# ╟─fab5b940-a062-4907-b4eb-7cce30581d95
# ╠═b84ec704-59ab-4443-b8cf-97f83eb59f28
# ╟─5a10c799-a603-49e3-9610-f9290590bd41
# ╠═a7a36d22-e6d9-4a96-ae94-bfc50e8d42ef
# ╟─7aa0aa07-25ca-470e-87b5-957ec95b45f9
# ╠═6986fd27-7da6-4cce-9604-42fa5f717de6
# ╠═22cb8b8a-f511-4996-939b-4b88f8d1d38c
# ╟─b075a56b-a22c-4465-b6d0-422342a91acf
# ╟─90c84c45-8c06-4e54-a674-dd596d66cf44
# ╠═c873584e-9a93-436a-8868-59fb71db560d
# ╠═f7f561d7-51fc-451a-a3a3-5cc4955da655
# ╟─c76c7b5e-e31f-4dc9-addc-3b9156354678
# ╟─4fed0344-f8b2-4991-ad34-f20da38d3746
# ╟─f62915be-8564-4107-a8a3-28e3547c4ff1
# ╠═9a813e6f-f58f-4835-acc5-a3f68c62256d
# ╠═1fbcd1ef-3d7b-4e5b-84c8-ae20523c02ba
# ╠═e116d21b-6f97-4b72-9d4c-e4ef7ae1201c
# ╠═bfa1187b-6ebd-44b3-a38e-235970da28b9
# ╟─169b34f6-c357-4fa8-92a5-058adc514ed9
# ╠═295e4a52-4335-48cf-b722-9eca908648c7
# ╠═6b0a0764-6fce-481d-83b1-a4e94a5f16eb
# ╟─51ca3789-f6ee-4ba3-8895-d4c0ea47feb5
# ╠═8778e425-c7c3-43ab-acd6-b3e2176731c6
# ╠═ce66d754-379c-4fc4-a95f-9a8c85691047
# ╟─c2da2c1c-b0ab-46f1-a386-303443a11a5e
# ╠═3d76d57a-8e56-4453-a80e-d2e28da599b4
# ╟─75e68068-8796-4745-be38-a901a91a47a7
# ╠═18fa9315-7fa7-4b43-a450-c7806a4c9f97
# ╠═e7fa3660-3d1f-4ace-b9f4-c7a86c2044ca
# ╟─6c3168db-c972-456c-b22a-2efa17f131ef
# ╠═17f8a3c3-0ac9-4ebd-84e5-408574f4569d
# ╟─11bea3f9-9066-45db-afba-f7b501c91ab0
# ╠═d9b96204-387a-44ec-8a2a-52128e38f9de
# ╟─cca35b03-4f76-4e28-83d3-ed043522bfdb
# ╠═cff56dc3-f2ce-4da5-8e28-b9dc0e557c97
# ╟─fa3c626e-4c54-42f4-b69a-87233462cb98
# ╠═455b4b49-39f9-4de8-b3a4-eb4b56967f62
# ╟─24d9c062-c0bd-4916-8c18-9f65bba676c0
# ╠═61037f62-00e5-4747-ab99-48e8f4d83382
# ╟─b2cf24cb-fd6a-424c-98b4-5d41119685d8
# ╠═90e83716-2170-46a7-bd8e-f1b0fd64fe2f
# ╟─652beae9-71b8-4103-86dc-87c0b133f3de
# ╠═2429d7b9-057d-4202-b5ca-09b699036573
# ╠═dd3e87a7-ba6d-44c9-9733-46f922daf56b
# ╠═28f8105b-06e4-4e3e-9286-b85b7d3c277e
# ╠═6c8788fa-7a09-4c95-bd04-8399769c2cef
# ╠═5e2d1ad0-be6a-415c-9887-e1fede4effe1
# ╠═15f37365-0aee-41ba-aa27-09b8eebe0999
# ╠═f8fda4db-8a8a-46b6-a44f-e92ae4db3e31
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
