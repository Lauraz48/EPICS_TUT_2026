# Materials for EPICS 2026 Tutorial Session (Coding Workshop)

This repository contains the materials used for the EPICS 2026 tutorial session.  
It focuses on hands-on coding exercises and demonstrations for the effective use of [`OpenDSSDirect.jl`](https://dss-extensions.org/OpenDSSDirect.jl/stable/) and [`PowerModelsDistribution.jl`](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/index.html) to model and solve unbalanced distribution system problems.

## Repository Structure

- **Notebook/**  
Contains Pluto notebooks used in the tutorial sessions. These notebooks are designed to be interactive and are intended to guide participants through key concepts and implementations.

- **Data/**
Contains the distribution network data used in the simulations, including a 26-bus low-voltage distribution network with and without time-dependant features and a lv test case.

## Repository Content

The repository is organised into the following components and examples:

### 1. Three-Phase Four-Wire Unbalanced Power Flow

Script: `play.jl`

This section covers unbalanced power flow analysis and includes:
- Power flow modelling using `OpenDSSDirect.jl`
- Power flow modelling using `PowerModelsDistribution.jl (PMD)`, including
  - Native PMD power flow formulation
  - Using Ipopt as a nonlinear equation solver
- (Comparison of results between OpenDSS and PMD)
- (An interactive “playground” for exploring voltage profiles under varying load conditions)

### 2. Three-Phase Four-Wire Unbalanced Optimal Power Flow

This section focuses on optimal power flow formulations and includes:
- Snapshot OPF: `3_opf_26bus_wdistance.jl`  
- Multinetwork / Time-Series OPF: `3_opf_26bus_ts_wdistance.jl`  

### 3. Additional Examples for Beginners

This section provides introductory examples demonstrating the use of `PowerModelsDistribution`, including:
- `Beginners Guide.jl`
- `Basics.jl`
- `Extending PowerModelsDistribution.jl`


*Note: Basic familiarity with the Julia programming language is assumed;
no prior experience with `OpenDSSDirect.jl` or `PowerModelsDistribution.jl` is required.*
