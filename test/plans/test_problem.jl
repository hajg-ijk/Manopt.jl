using Manopt, Manifolds, Test

@testset "Manopt Problem" begin
    @testset "Test generic Problem functions" begin
        M = Euclidean(3)
        f(M, p) = norm(p)^2
        grad_f(M, p) = 2 * p
        moa = ManifoldGradientObjective(f, grad_f)
        cpa = DefaultManoptProblem(M, moa)
        @test Manopt.evaluation_type(cpa) === AllocatingEvaluation

        grad_f!(M, X, p) = (X .= 2 * p)
        moi = ManifoldGradientObjective(f, grad_f!; evaluation=InplaceEvaluation())
        cpi = DefaultManoptProblem(M, moi)
        @test Manopt.evaluation_type(cpi) === InplaceEvaluation
    end
    @testset "set_*_parameter functions" begin
        f(M, p) = 1 # dummy cost
        mco = ManifoldCostObjective(f)
        dmp = DefaultManoptProblem(Euclidean(3), mco)
        # has no effect but does not error
        set_manopt_parameter!(f, :Dummy, 1)
        set_manopt_parameter!(dmp, :Cost, :Dummy, 1)
        set_manopt_parameter!(mco, :Cost, :Dummy, 1)
        # but the objective here does not have a gradient
        @test_throws MethodError set_manopt_parameter!(dmp, :Gradient, :Dummy, 1)
        @test_throws MethodError set_manopt_parameter!(mco, :Gradient, :Dummy, 1)
    end
end
