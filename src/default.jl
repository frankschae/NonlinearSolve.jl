"""
    RobustMultiNewton(; concrete_jac = nothing, linsolve = nothing, precs = DEFAULT_PRECS,
                        adkwargs...)

A polyalgorithm focused on robustness. It uses a mixture of Newton methods with different
globalizing techniques (trust region updates, line searches, etc.) in order to find a
method that is able to adequately solve the minimization problem.

Basically, if this algorithm fails, then "most" good ways of solving your problem fail and
you may need to think about reformulating the model (either there is an issue with the model,
or more precision / more stable linear solver choice is required).

### Keyword Arguments

  - `autodiff`: determines the backend used for the Jacobian. Note that this argument is
    ignored if an analytical Jacobian is passed, as that will be used instead. Defaults to
    `AutoForwardDiff()`. Valid choices are types from ADTypes.jl.
  - `concrete_jac`: whether to build a concrete Jacobian. If a Krylov-subspace method is used,
    then the Jacobian will not be constructed and instead direct Jacobian-vector products
    `J*v` are computed using forward-mode automatic differentiation or finite differencing
    tricks (without ever constructing the Jacobian). However, if the Jacobian is still needed,
    for example for a preconditioner, `concrete_jac = true` can be passed in order to force
    the construction of the Jacobian.
  - `linsolve`: the [LinearSolve.jl](https://github.com/SciML/LinearSolve.jl) used for the
    linear solves within the Newton method. Defaults to `nothing`, which means it uses the
    LinearSolve.jl default algorithm choice. For more information on available algorithm
    choices, see the [LinearSolve.jl documentation](https://docs.sciml.ai/LinearSolve/stable/).
  - `precs`: the choice of preconditioners for the linear solver. Defaults to using no
    preconditioners. For more information on specifying preconditioners for LinearSolve
    algorithms, consult the
    [LinearSolve.jl documentation](https://docs.sciml.ai/LinearSolve/stable/).
"""
@concrete struct RobustMultiNewton{CJ} <: AbstractNewtonAlgorithm{CJ, Nothing}
    adkwargs
    linsolve
    precs
end

# When somethin's strange, and numerical
# who you gonna call?
# Robusters!
const Robusters = RobustMultiNewton

function RobustMultiNewton(; concrete_jac = nothing, linsolve = nothing,
    precs = DEFAULT_PRECS, adkwargs...)
    return RobustMultiNewton{_unwrap_val(concrete_jac)}(adkwargs, linsolve, precs)
end

@concrete mutable struct RobustMultiNewtonCache{iip} <: AbstractNonlinearSolveCache{iip}
    caches
    alg
    current::Int
end

function SciMLBase.__init(prob::NonlinearProblem{uType, iip}, alg::RobustMultiNewton,
    args...; kwargs...) where {uType, iip}
    @unpack adkwargs, linsolve, precs = alg

    algs = (TrustRegion(; linsolve, precs, adkwargs...),
        TrustRegion(; linsolve, precs,
            radius_update_scheme = RadiusUpdateSchemes.Bastin, adkwargs...),
        NewtonRaphson(; linsolve, precs, linesearch = BackTracking(), adkwargs...),
        TrustRegion(; linsolve, precs,
            radius_update_scheme = RadiusUpdateSchemes.NLsolve, adkwargs...),
        TrustRegion(; linsolve, precs,
            radius_update_scheme = RadiusUpdateSchemes.Fan, adkwargs...))

    return RobustMultiNewtonCache{iip}(map(solver -> SciMLBase.__init(prob, solver, args...;
                kwargs...), algs), alg, 1)
end

"""
    FastShortcutNonlinearPolyalg(; concrete_jac = nothing, linsolve = nothing,
                                   precs = DEFAULT_PRECS, adkwargs...)

A polyalgorithm focused on balancing speed and robustness. It first tries less robust methods
for more performance and then tries more robust techniques if the faster ones fail.

### Keyword Arguments

  - `autodiff`: determines the backend used for the Jacobian. Note that this argument is
    ignored if an analytical Jacobian is passed, as that will be used instead. Defaults to
    `AutoForwardDiff()`. Valid choices are types from ADTypes.jl.
  - `concrete_jac`: whether to build a concrete Jacobian. If a Krylov-subspace method is used,
    then the Jacobian will not be constructed and instead direct Jacobian-vector products
    `J*v` are computed using forward-mode automatic differentiation or finite differencing
    tricks (without ever constructing the Jacobian). However, if the Jacobian is still needed,
    for example for a preconditioner, `concrete_jac = true` can be passed in order to force
    the construction of the Jacobian.
  - `linsolve`: the [LinearSolve.jl](https://github.com/SciML/LinearSolve.jl) used for the
    linear solves within the Newton method. Defaults to `nothing`, which means it uses the
    LinearSolve.jl default algorithm choice. For more information on available algorithm
    choices, see the [LinearSolve.jl documentation](https://docs.sciml.ai/LinearSolve/stable/).
  - `precs`: the choice of preconditioners for the linear solver. Defaults to using no
    preconditioners. For more information on specifying preconditioners for LinearSolve
    algorithms, consult the
    [LinearSolve.jl documentation](https://docs.sciml.ai/LinearSolve/stable/).
"""
@concrete struct FastShortcutNonlinearPolyalg{CJ} <: AbstractNewtonAlgorithm{CJ, Nothing}
    adkwargs
    linsolve
    precs
end

function FastShortcutNonlinearPolyalg(; concrete_jac = nothing, linsolve = nothing,
    precs = DEFAULT_PRECS, adkwargs...)
    return FastShortcutNonlinearPolyalg{_unwrap_val(concrete_jac)}(adkwargs, linsolve,
        precs)
end

@concrete mutable struct FastShortcutNonlinearPolyalgCache{iip} <:
                         AbstractNonlinearSolveCache{iip}
    caches
    alg
    current::Int
end

function FastShortcutNonlinearPolyalgCache(; concrete_jac = nothing, linsolve = nothing,
    precs = DEFAULT_PRECS, adkwargs...)
    return FastShortcutNonlinearPolyalgCache{_unwrap_val(concrete_jac)}(adkwargs, linsolve,
        precs)
end

function SciMLBase.__init(prob::NonlinearProblem{uType, iip},
    alg::FastShortcutNonlinearPolyalg, args...; kwargs...) where {uType, iip}
    @unpack adkwargs, linsolve, precs = alg

    algs = (
        # Klement(),
        # Broyden(),
        NewtonRaphson(; linsolve, precs, adkwargs...),
        NewtonRaphson(; linsolve, precs, linesearch = BackTracking(), adkwargs...),
        TrustRegion(; linsolve, precs, adkwargs...),
        TrustRegion(; linsolve, precs,
            radius_update_scheme = RadiusUpdateSchemes.Bastin, adkwargs...))

    return FastShortcutNonlinearPolyalgCache{iip}(map(solver -> SciMLBase.__init(prob,
                solver, args...; kwargs...), algs), alg, 1)
end

# This version doesn't allocate all the caches!
function SciMLBase.__solve(prob::NonlinearProblem{uType, iip},
    alg::FastShortcutNonlinearPolyalg, args...; kwargs...) where {uType, iip}
    @unpack adkwargs, linsolve, precs = alg

    algs = [
        iip ? Klement() : nothing, # Klement not yet implemented for IIP
        iip ? Broyden() : nothing, # Broyden not yet implemented for IIP
        NewtonRaphson(; linsolve, precs, adkwargs...),
        NewtonRaphson(; linsolve, precs, linesearch = BackTracking(), adkwargs...),
        TrustRegion(; linsolve, precs, adkwargs...),
        TrustRegion(; linsolve, precs,
            radius_update_scheme = RadiusUpdateSchemes.Bastin, adkwargs...),
    ]
    filter!(!isnothing, algs)

    sols = Vector{SciMLBase.NonlinearSolution}(undef, length(algs))

    for (i, solver) in enumerate(algs)
        sols[i] = SciMLBase.__solve(prob, solver, args...; kwargs...)
        if SciMLBase.successful_retcode(sols[i])
            return SciMLBase.build_solution(prob, alg, sols[i].u, sols[i].resid;
                sols[i].retcode, sols[i].stats, original = sols[i])
        end
    end

    resids = map(Base.Fix2(getproperty, resid), sols)
    minfu, idx = findmin(DEFAULT_NORM, resids)

    return SciMLBase.build_solution(prob, alg, sols[idx].u, sols[idx].resid;
        sols[idx].retcode, sols[idx].stats, original = sols[idx])
end

function SciMLBase.__solve(prob::NonlinearProblem{uType, true}, alg::FastShortcutNonlinearPolyalg, args...;
    kwargs...) where {uType}

    adkwargs = alg.adkwargs
    linsolve = alg.linsolve
    precs = alg.precs

    sol1 = SciMLBase.__solve(prob, NewtonRaphson(;linsolve, precs, adkwargs...), args...; kwargs...)
    if SciMLBase.successful_retcode(sol1)
        return SciMLBase.build_solution(prob, alg, sol1.u, sol1.resid;
                                        sol1.retcode, sol1.stats)
    end

    sol2 = SciMLBase.__solve(prob, NewtonRaphson(;linsolve, precs, linesearch=BackTracking(), adkwargs...), args...; kwargs...)
    if SciMLBase.successful_retcode(sol2)
        return SciMLBase.build_solution(prob, alg, sol2.u, sol2.resid;
                                        sol2.retcode, sol2.stats)
    end

    sol3 = SciMLBase.__solve(prob, TrustRegion(;linsolve, precs, adkwargs...), args...; kwargs...)
    if SciMLBase.successful_retcode(sol3)
        return SciMLBase.build_solution(prob, alg, sol3.u, sol3.resid;
                                        sol3.retcode, sol3.stats)
    end

    sol4 = SciMLBase.__solve(prob,  TrustRegion(;linsolve, precs, radius_update_scheme = RadiusUpdateSchemes.Bastin, adkwargs...), args...; kwargs...)
    if SciMLBase.successful_retcode(sol4)
        return SciMLBase.build_solution(prob, alg, sol4.u, sol4.resid;
                                        sol4.retcode, sol4.stats)
    end

    resids = (sol1.resid, sol2.resid, sol3.resid, sol4.resid)
    minfu, idx = findmin(DEFAULT_NORM, resids)

    if idx == 1
        SciMLBase.build_solution(prob, alg, sol1.u, sol1.resid;
                                        sol1.retcode, sol1.stats)
    elseif idx == 2
        SciMLBase.build_solution(prob, alg, sol2.u, sol2.resid;
                                        sol2.retcode, sol2.stats)
    elseif idx == 3
        SciMLBase.build_solution(prob, alg, sol3.u, sol3.resid;
                                sol3.retcode, sol3.stats)
    elseif idx == 4
        SciMLBase.build_solution(prob, alg, sol4.u, sol4.resid;
                                sol4.retcode, sol4.stats)
    else
        error("Unreachable reached, 박정석")
    end

end

## General shared polyalg functions

function perform_step!(cache::Union{RobustMultiNewtonCache,
    FastShortcutNonlinearPolyalgCache})
    current = cache.current
    1 ≤ current ≤ length(cache.caches) || error("Current choices shouldn't get here!")

    current_cache = cache.caches[current]
    while not_terminated(current_cache)
        perform_step!(current_cache)
    end

    return nothing
end

function SciMLBase.solve!(cache::Union{RobustMultiNewtonCache,
    FastShortcutNonlinearPolyalgCache})
    current = cache.current
    1 ≤ current ≤ length(cache.caches) || error("Current choices shouldn't get here!")

    current_cache = cache.caches[current]
    while current ≤ length(cache.caches) #  && !all(terminated[current:end])
        sol_tmp = solve!(current_cache)
        SciMLBase.successful_retcode(sol_tmp) && break
        current += 1
        cache.current = current
        current_cache = cache.caches[current]
    end

    if current ≤ length(cache.caches)
        retcode = ReturnCode.Success

        stats = cache.caches[current].stats
        u = cache.caches[current].u
        fu = get_fu(cache.caches[current])

        return SciMLBase.build_solution(cache.caches[1].prob, cache.alg, u, fu;
            retcode, stats)
    else
        retcode = ReturnCode.MaxIters

        fus = get_fu.(cache.caches)
        minfu, idx = findmin(cache.caches[1].internalnorm, fus)
        stats = cache.caches[idx].stats
        u = cache.caches[idx].u

        return SciMLBase.build_solution(cache.caches[idx].prob, cache.alg, u, fus[idx];
            retcode, stats)
    end
end

function SciMLBase.reinit!(cache::Union{RobustMultiNewtonCache,
        FastShortcutNonlinearPolyalgCache}, args...; kwargs...)
    for c in cache.caches
        SciMLBase.reinit!(c, args...; kwargs...)
    end
end

## Defaults

function SciMLBase.__init(prob::NonlinearProblem{uType, iip}, alg::Nothing, args...;
    kwargs...) where {uType, iip}
    SciMLBase.__init(prob, FastShortcutNonlinearPolyalg(), args...; kwargs...)
end

function SciMLBase.__solve(prob::NonlinearProblem{uType, iip}, alg::Nothing, args...;
    kwargs...) where {uType, iip}
    SciMLBase.__solve(prob, FastShortcutNonlinearPolyalg(), args...; kwargs...)
end
