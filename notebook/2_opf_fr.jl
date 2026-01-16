### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# ╔═╡ 6d584d7f-09fe-44ca-99cf-24be95ae90a7
begin
	import Pkg
	Pkg.add(url="https://github.com/frederikgeth/GPSTTopic82024")
end

# ╔═╡ 937b4bfc-e198-4be1-a6c3-4c640ce0c4df
begin
	using GPSTTopic82024
	using PowerModelsDistribution
	using Ipopt
	using Plots
	using DataFrames
	using CSV
	ipopt = Ipopt.Optimizer
end

# ╔═╡ 24840950-e94a-11f0-079c-c3f1e7c48752
md"""
# 2. Optimal Power Flow: realistic network
_reference: Fred GPSTTopic82024_
"""

# ╔═╡ f8b24153-c590-4e1a-892a-66a2ffc70c7a
md"""
## 2.1 Import Packages
"""

# ╔═╡ 60a9c0da-12ac-41e8-b476-3ec68cc4f3a4
md"""
## 2.2 Load Network Data
"""

# ╔═╡ 2111fd6f-0644-4836-a171-2e91a2011dd6
pkg_root = dirname(dirname(pathof(GPSTTopic82024)))

# ╔═╡ adb3cc98-11e7-46ff-ad70-b672b480045d
casepath = joinpath(pkg_root, "data", "LV9_258bus")

# ╔═╡ 99174e25-093f-4a9d-a6b0-dff5930482f6
file = "$casepath/Master.dss"

# ╔═╡ 43fa077d-9b50-466a-859d-a31a1de597e6
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

# ╔═╡ 54656b7f-0df6-4958-8a9b-e25355f8f86d
busdistancesdf = CSV.read(joinpath(casepath, "busdistances.csv"), DataFrame)

# ╔═╡ fb8eeab3-feee-4a87-87cb-d9c825da7b53
busdistances_dict = Dict(busdistancesdf.Bus[i] => busdistancesdf.busdistances[i] for i in 1:nrow(busdistancesdf))

# ╔═╡ 52babb7a-6c70-4abf-8747-1cf7fe551cab
md"""
## 2.3 Data Models
"""

# ╔═╡ 9d570edb-61ef-4da5-bb5a-c8dc371673f0
md"""
### Engineering data model
"""

# ╔═╡ 18b2e7c7-9d1c-423b-b909-464106a2e506
vscale = 1; loadscale = 1

# ╔═╡ ea2fceb8-db8f-4adf-8f7e-f6fd35a717a4
eng4w = parse_file(file, transformations=[transform_loops!, remove_all_bounds!])

# ╔═╡ ad6277fb-215d-4117-b1d9-932887498ff3
eng4w["voltage_source"]["source"]["vm"]

# ╔═╡ b75b7134-4921-45a1-9fb0-cf91570ac0fd
begin
	eng4w["conductor_ids"] = 1:4
	eng4w["settings"]["sbase_default"] = 1
	eng4w["voltage_source"]["source"]["rs"] *=0
	eng4w["voltage_source"]["source"]["xs"] *=0
	eng4w["voltage_source"]["source"]["vm"] *=vscale
end

# ╔═╡ d06b8ec9-a5a5-48b8-b078-37a71fc3716f
reduce_line_series!(eng4w)

# ╔═╡ 75a1eff8-cea4-4c64-b662-f5f72177bfa9
md"""
### Mathematical model and OPF setup
"""

# ╔═╡ b9cd374b-68ee-4d7c-a289-0c17eb758698
math4w = transform_data_model(eng4w, kron_reduce=false, phase_project=false)

# ╔═╡ e8c662a0-bcc8-45fc-9d46-79d6852584e9
math4w["bus_lookup"]

# ╔═╡ c2425a11-a43b-46fb-8a26-0fe2fb839ef2
add_start_vrvi!(math4w)

# ╔═╡ fdcec4f8-971e-4082-bf9c-23a00a432423
eng4w["bus"]["b2349"]

# ╔═╡ 449c3114-7206-4414-ae0e-062f540dca96
math4w["bus"]["190"] # more properties to play with than in eng4w

# ╔═╡ 70e93032-93df-4218-a383-4f493d60e91d
for (i,bus) in math4w["bus"]
	if bus["bus_type"] != 3 && !startswith(bus["source_id"], "transformer")
		bus["vmax"] = ones(4)*2
		bus["vmin"] = zeros(4)
	else
		@show bus
	end
end										

# ╔═╡ a5f6d53a-4ace-44e8-a679-ae416b32eb79
math4w["gen"]["1"]

# ╔═╡ 31805916-6351-481e-8bd9-158779712cc1
for (g,gen) in math4w["gen"]
	math4w["gen"]["1"]["cost"] = [1, 1, 1]
	s = 1000
	gen["pmin"] = -s*ones(3)
	gen["pmax"] = s*ones(3)
	gen["qmin"] = -s*ones(3)
	gen["qmax"] = s*ones(3)
	gen["connections"] = collect(1:4)
end

# ╔═╡ 4f82885a-adde-4c26-bc6d-e9506afd1334
math4w["gen"]["1"]

# ╔═╡ f3c17aa1-62d1-4d9d-aef5-281bc47e38d4
math4w["load"]["1"]

# ╔═╡ c98f0f29-dedd-4ac2-8f4d-0a9facdbdc80
for (d,load) in math4w["load"]
	load["pd"] .*= loadscale
	load["qd"] .*= loadscale
end

# ╔═╡ 5ec4878a-00e5-4026-b32a-5f979a915289
md"""
## 2.4 Solving OPF and Inspecting results
"""

# ╔═╡ 58dea99c-3862-494c-9418-3500045fa0c0
res = solve_mc_opf(math4w, IVRENPowerModel, ipopt)

# ╔═╡ cd163df5-5c04-4d66-99dd-226f3c41d19f
res["solution"]["bus"]

# ╔═╡ cfe32fa8-df67-40c7-b43e-8ed682839d8b
v_mag = Base.stack([hypot.(bus["vr"][1:4], bus["vi"][1:4]) for (b,bus) in res["solution"]["bus"]], dims=1)

# ╔═╡ 126e721e-d4f1-4f77-baca-17d577b37c74
begin
	plot(v_mag, label=["a" "b" "c" "n"])
	plot!([0; length(res["solution"]["bus"])], [0.9; 0.9], label="vmin")
	plot!([0; length(res["solution"]["bus"])], [1.1; 1.1], label="vmax")
	ylabel!("V (pu)")
	xlabel!("bus id (-)")
end

# ╔═╡ Cell order:
# ╟─24840950-e94a-11f0-079c-c3f1e7c48752
# ╟─f8b24153-c590-4e1a-892a-66a2ffc70c7a
# ╠═6d584d7f-09fe-44ca-99cf-24be95ae90a7
# ╠═937b4bfc-e198-4be1-a6c3-4c640ce0c4df
# ╟─60a9c0da-12ac-41e8-b476-3ec68cc4f3a4
# ╠═2111fd6f-0644-4836-a171-2e91a2011dd6
# ╠═adb3cc98-11e7-46ff-ad70-b672b480045d
# ╠═99174e25-093f-4a9d-a6b0-dff5930482f6
# ╠═43fa077d-9b50-466a-859d-a31a1de597e6
# ╠═54656b7f-0df6-4958-8a9b-e25355f8f86d
# ╠═fb8eeab3-feee-4a87-87cb-d9c825da7b53
# ╟─52babb7a-6c70-4abf-8747-1cf7fe551cab
# ╟─9d570edb-61ef-4da5-bb5a-c8dc371673f0
# ╠═18b2e7c7-9d1c-423b-b909-464106a2e506
# ╠═ea2fceb8-db8f-4adf-8f7e-f6fd35a717a4
# ╠═ad6277fb-215d-4117-b1d9-932887498ff3
# ╠═b75b7134-4921-45a1-9fb0-cf91570ac0fd
# ╠═d06b8ec9-a5a5-48b8-b078-37a71fc3716f
# ╟─75a1eff8-cea4-4c64-b662-f5f72177bfa9
# ╠═b9cd374b-68ee-4d7c-a289-0c17eb758698
# ╠═e8c662a0-bcc8-45fc-9d46-79d6852584e9
# ╠═c2425a11-a43b-46fb-8a26-0fe2fb839ef2
# ╠═fdcec4f8-971e-4082-bf9c-23a00a432423
# ╠═449c3114-7206-4414-ae0e-062f540dca96
# ╠═70e93032-93df-4218-a383-4f493d60e91d
# ╠═a5f6d53a-4ace-44e8-a679-ae416b32eb79
# ╠═31805916-6351-481e-8bd9-158779712cc1
# ╠═4f82885a-adde-4c26-bc6d-e9506afd1334
# ╠═f3c17aa1-62d1-4d9d-aef5-281bc47e38d4
# ╠═c98f0f29-dedd-4ac2-8f4d-0a9facdbdc80
# ╟─5ec4878a-00e5-4026-b32a-5f979a915289
# ╠═58dea99c-3862-494c-9418-3500045fa0c0
# ╠═cd163df5-5c04-4d66-99dd-226f3c41d19f
# ╠═cfe32fa8-df67-40c7-b43e-8ed682839d8b
# ╠═126e721e-d4f1-4f77-baca-17d577b37c74
