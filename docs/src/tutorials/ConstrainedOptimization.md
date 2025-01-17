```@meta
EditURL = "/tutorials/ConstrainedOptimization.jl"
```
```@raw html
<style>
    table {
        display: table !important;
        margin: 2rem auto !important;
        border-top: 2pt solid rgba(0,0,0,0.2);
        border-bottom: 2pt solid rgba(0,0,0,0.2);
    }

    pre, div {
        margin-top: 1.4rem !important;
        margin-bottom: 1.4rem !important;
    }

    .code-output {
        padding: 0.7rem 0.5rem !important;
    }

    .admonition-body {
        padding: 0em 1.25em !important;
    }
</style>

<!-- PlutoStaticHTML.Begin -->
<!--
    # This information is used for caching.
    [PlutoStaticHTML.State]
    input_sha = "71ef82564c4e0683ffff4b7b14c234abe9a61d250d6070dd4dccfa45f90018a7"
    julia_version = "1.8.4"
-->

<div class="markdown"><h1>How to do Constrained Optimization</h1><p>This tutorial is a short introduction to using solvers for constraint optimisation in <a href="https://manoptjl.org"><code>Manopt.jl</code></a>.</p></div>


```
## Introduction
```@raw html
<div class="markdown">
<p>A constraint optimisation problem is given by</p><p class="tex">$$\tag{P}
\begin{align*}
\operatorname*{arg\,min}_{p\in\mathcal M} &amp; f(p)\\
\text{such that} &amp;\quad g(p) \leq 0\\
&amp;\quad h(p) = 0,\\
\end{align*}$$</p><p>where <span class="tex">$f\colon \mathcal M → ℝ$</span> is a cost function, and <span class="tex">$g\colon \mathcal M → ℝ^m$</span> and <span class="tex">$h\colon \mathcal M → ℝ^n$</span> are the inequality and equality constraints, respectively. The <span class="tex">$\leq$</span> and <span class="tex">$=$</span> in (P) are meant elementwise.</p><p>This can be seen as a balance between moving constraints into the geometry of a manifold <span class="tex">$\mathcal M$</span> and keeping some, since they can be handled well in algorithms, see <a class="footnote" href="#footnote-BergmannHerzog2019">[BergmannHerzog2019]</a>, <a class="footnote" href="#footnote-LiuBoumal2020">[LiuBoumal2020]</a> for details.</p></div>


```
## Setup
```@raw html
<div class="markdown">
<p>If you open this notebook in Pluto locally it switches between two modes. If the tutorial is within the <code>Manopt.jl</code> repository, this notebook tries to use the local package in development mode. Otherwise, the file uses the Pluto pacakge management version.</p></div>








<div class="markdown"><p>Since the loading is a little complicated, we show, which versions of packages were installed in the following.</p></div>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    Pkg.status()
end</code></pre>
<pre id="plutouiterminal">�[32m�[1mStatus�[22m�[39m `/private/var/folders/_v/wg192lpd3mb1lp55zz7drpcw0000gn/T/jl_4eRURe/Project.toml`
 �[90m [31c24e10] �[39mDistributions v0.25.79
 �[90m [1cead3c2] �[39mManifolds v0.8.42
 �[90m [0fc0a36d] �[39mManopt v0.4.0 `~/Repositories/Julia/Manopt.jl`
 �[90m [7f904dfe] �[39mPlutoUI v0.7.49
 �[90m [37e2e46d] �[39mLinearAlgebra
 �[90m [44cfe95a] �[39mPkg v1.8.0
 �[90m [9a3f8284] �[39mRandom
</pre>

<pre class='language-julia'><code class='language-julia'>Random.seed!(12345);</code></pre>



<div class="markdown"><p>In this tutorial we want to look at different ways to specify the problem and its implications. We start with specifying an example problems to illustrayte the different available forms.</p></div>


<div class="markdown"><p>We will consider the problem of a Nonnegative PCA, cf. Section 5.1.2 in <a class="footnote" href="#footnote-LiuBoumal2020">[LiuBoumal2020]</a>:</p><p>let <span class="tex">$v_0 ∈ ℝ^d$</span>, <span class="tex">$\lVert v_0 \rVert=1$</span> be given spike signal, that is a signal that is sparse with only <span class="tex">$s=\lfloor δd \rfloor$</span> nonzero entries.</p><p class="tex">$$  Z = \sqrt{σ} v_0v_0^{\mathrm{T}}+N,$$</p><p>where <span class="tex">$\sigma$</span> is a signal-to-noise ratio and <span class="tex">$N$</span> is a matrix with random entries, where the diagonal entries are distributed with zero mean and standard deviation <span class="tex">$1/d$</span> on the off-diagonals and <span class="tex">$2/d$</span> on the daigonal</p></div>

<pre class='language-julia'><code class='language-julia'>d = 150; # dimension of v0</code></pre>


<pre class='language-julia'><code class='language-julia'>σ = 0.1^2; # SNR</code></pre>


<pre class='language-julia'><code class='language-julia'>δ = 0.1; s = Int(floor(δ * d)); # Sparsity</code></pre>


<pre class='language-julia'><code class='language-julia'>S = sample(1:d, s; replace=false);</code></pre>


<pre class='language-julia'><code class='language-julia'>v0 =  [i ∈ S ? 1 / sqrt(s) : 0.0 for i in 1:d];</code></pre>


<pre class='language-julia'><code class='language-julia'>N = rand(Normal(0, 1 / d), (d, d)); N[diagind(N, 0)] .= rand(Normal(0, 2 / d), d);</code></pre>


<pre class='language-julia'><code class='language-julia'> Z = Z = sqrt(σ) * v0 * transpose(v0) + N;</code></pre>



<div class="markdown"><p>In order to recover <span class="tex">$v_0$</span> we consider the constrained optimisation problem on the sphere <span class="tex">$\mathcal S^{d-1}$</span> given by</p><p class="tex">$$\begin{align*}
\operatorname*{arg\,min}_{p\in\mathcal S^{d-1}} &amp; -p^{\mathrm{T}}Zp^{\mathrm{T}}\\
\text{such that} &amp;\quad p \geq 0\\
\end{align*}$$</p><p>or in the previous notation <span class="tex">$f(p) = -p^{\mathrm{T}}Zp^{\mathrm{T}}$</span> and <span class="tex">$g(p) = -p$</span>. We first initialize the manifold under consideration</p></div>

<pre class='language-julia'><code class='language-julia'>M = Sphere(d - 1)</code></pre>
<pre class="code-output documenter-example-output" id="var-M">Sphere(149, ℝ)</pre>


```
## A first Augmented Lagrangian Run
```@raw html
<div class="markdown">
<p>We first defined <span class="tex">$f$</span>  and <span class="tex">$g$</span> as usual functions</p></div>

<pre class='language-julia'><code class='language-julia'>f(M, p) = -transpose(p) * Z * p;</code></pre>


<pre class='language-julia'><code class='language-julia'>g(M, p) = -p;</code></pre>



<div class="markdown"><p>since <span class="tex">$f$</span> is a functions defined in the embedding <span class="tex">$ℝ^d$</span> as well, we obtain its gradient by projection.</p></div>

<pre class='language-julia'><code class='language-julia'>grad_f(M, p) = project(M, p, -transpose(Z) * p - Z * p);</code></pre>



<div class="markdown"><p>For the constraints this is a little more involved, since each function <span class="tex">$g_i = g(p)_i = p_i$</span> has to return its own gradient. These are again in the embedding just <span class="tex">$\operatorname{grad} g_i(p) = -e_i$</span> the <span class="tex">$i$</span> th unit vector. We can project these again onto the tangent space at <span class="tex">$p$</span>:</p></div>

<pre class='language-julia'><code class='language-julia'>grad_g(M, p) = project.(
    Ref(M), Ref(p), [[i == j ? -1.0 : 0.0 for j in 1:d] for i in 1:d]
);</code></pre>



<div class="markdown"><p>We further start in a random point:</p></div>

<pre class='language-julia'><code class='language-julia'>x0 = rand(M);</code></pre>



<div class="markdown"><p>Let's check a few things for the initial point</p></div>

<pre class='language-julia'><code class='language-julia'>f(M, x0)</code></pre>
<pre class="code-output documenter-example-output" id="var-hash480326">-0.000548773233810874</pre>


<div class="markdown"><p>How much the function g is positive</p></div>

<pre class='language-julia'><code class='language-julia'>maximum(g(M, x0))</code></pre>
<pre class="code-output documenter-example-output" id="var-hash676505">0.2277254978939742</pre>


<div class="markdown"><p>Now as a first method we can just call the <a href="https://manoptjl.org/stable/solvers/augmented_Lagrangian_method/">Augmented Lagrangian Method</a> with a simple call:</p></div>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @time global v1 = augmented_Lagrangian_method(
    	M, f, grad_f, x0; g=g, grad_g=grad_g,
    	debug=[:Iteration, :Cost, :Stop, " | ", :Change, 50, "\n"],
    );
end</code></pre>
<pre id="plutouiterminal">Initial F(x): -0.000549 |
# 50    F(x): -0.116647 | Last Change: 1.039050
# 100   F(x): -0.116647 | Last Change: 0.000000
The value of the variable (ϵ) is smaller than or equal to its threshold (1.0e-6).
The algorithm performed a step with a change (0.0) less than 1.0e-6.
  5.079194 seconds (23.66 M allocations: 10.991 GiB, 13.36% gc time, 62.27% compilation time)
</pre>


<div class="markdown"><p>Now we have both a lower function value and the point is nearly within the constraints, ... up to numerical inaccuracies</p></div>

<pre class='language-julia'><code class='language-julia'>f(M, v1)</code></pre>
<pre class="code-output documenter-example-output" id="var-hash810540">-0.11664703552381685</pre>

<pre class='language-julia'><code class='language-julia'>maximum( g(M, v1) )</code></pre>
<pre class="code-output documenter-example-output" id="var-hash168124">7.959772487718166e-11</pre>


```
## A faster Augmented Lagrangian Run
```@raw html
<div class="markdown">
</div>


<div class="markdown"><p>Now this is a little slow, so we can modify two things, that we will directly do both – but one could also just change one of these – :</p><ol><li><p>Gradients should be evaluated in place, so for example</p></li></ol></div>

<pre class='language-julia'><code class='language-julia'>grad_f!(M, X, p) = project!(M, X, p, -transpose(Z) * p - Z * p);</code></pre>



<div class="markdown"><ol start="2"><li><p>The constraints are currently always evaluated all together, since the function <code>grad_g</code> always returns a vector of gradients.</p></li></ol><p>We first change the constraints function into a vector of functions. We further change the gradient <em>both</em> into a vector of gradient functions <span class="tex">$\operatorname{grad} g_i, i=1,\ldots,d$</span>, <em>as well as</em> gradients that are computed in place.</p></div>

<pre class='language-julia'><code class='language-julia'>g2 = [(M, p) -&gt; -p[i] for i in 1:d];</code></pre>


<pre class='language-julia'><code class='language-julia'>grad_g2! = [
    (M, X, p) -&gt; project!(M, X, p, [i == j ? -1.0 : 0.0 for j in 1:d]) for i in 1:d
];</code></pre>


<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @time global v2 = augmented_Lagrangian_method(
    	M, f, grad_f!, x0; g=g2, grad_g=grad_g2!, evaluation=InplaceEvaluation(),
    	debug=[:Iteration, :Cost, :Stop, " | ", :Change, 50, "\n"],
    );
end</code></pre>
<pre id="plutouiterminal">Initial F(x): -0.000549 |
# 50    F(x): -0.116647 | Last Change: 1.038985
# 100   F(x): -0.116647 | Last Change: 0.000000
The value of the variable (ϵ) is smaller than or equal to its threshold (1.0e-6).
The algorithm performed a step with a change (0.0) less than 1.0e-6.
  3.824243 seconds (13.86 M allocations: 9.038 GiB, 12.41% gc time, 19.65% compilation time)
</pre>


<div class="markdown"><p>As a technical remark: Note that (by default) the change to <a href="https://manoptjl.org/stable/plans/problem/#Manopt.InplaceEvaluation"><code>InplaceEvaluation</code></a>s affects both the constrained solver as well as the inner solver of the subproblem in each iteration.</p></div>

<pre class='language-julia'><code class='language-julia'>f(M, v2)</code></pre>
<pre class="code-output documenter-example-output" id="var-hash792719">-0.1166470569948405</pre>

<pre class='language-julia'><code class='language-julia'>maximum(g(M, v2))</code></pre>
<pre class="code-output documenter-example-output" id="var-hash126869">1.9323414582096286e-9</pre>


<div class="markdown"><p>These are the very similar to the previous values but the solver took much less time and less memory allocations.</p></div>


```
## Exact Penalty Method
```@raw html
<div class="markdown">
</div>


<div class="markdown"><p>As a second solver, we have the <a href="https://manoptjl.org/stable/solvers/exact_penalty_method/">Exact Penalty Method</a>, which currenlty is available with two smoothing variants, which make an inner solver for smooth optimisationm, that is by default again [quasi Newton] possible: <a href="https://manoptjl.org/stable/solvers/exact_penalty_method/#Manopt.LogarithmicSumOfExponentials"><code>LogarithmicSumOfExponentials</code></a> and <a href="https://manoptjl.org/stable/solvers/exact_penalty_method/#Manopt.LinearQuadraticHuber"><code>LinearQuadraticHuber</code></a>. We compare both here as well. The first smoothing technique is the default, so we can just call</p></div>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @time global v3 = exact_penalty_method(
    	M, f, grad_f!, x0; g=g2, grad_g=grad_g2!, evaluation=InplaceEvaluation(),
    	debug=[:Iteration, :Cost, :Stop, " | ", :Change, 50, "\n"],
    );
end</code></pre>
<pre id="plutouiterminal">Initial F(x): -0.000549 |
# 50    F(x): -0.115820 | Last Change: 1.018575
# 100   F(x): -0.116644 | Last Change: 0.015787
The value of the variable (ϵ) is smaller than or equal to its threshold (1.0e-6).
The algorithm performed a step with a change (0.0) less than 1.0e-6.
  1.247338 seconds (5.42 M allocations: 3.463 GiB, 14.21% gc time, 52.15% compilation time)
</pre>


<div class="markdown"><p>We obtain a similar cost value as for the Augmented Lagrangian Solver above, but here the constraint is actually fulfilled and not just numerically “on the boundary”.</p></div>

<pre class='language-julia'><code class='language-julia'>f(M, v3)</code></pre>
<pre class="code-output documenter-example-output" id="var-hash372234">-0.1166447384260138</pre>

<pre class='language-julia'><code class='language-julia'>maximum(g(M, v3))</code></pre>
<pre class="code-output documenter-example-output" id="var-hash114721">-3.856869829757542e-6</pre>


<div class="markdown"><p>The second smoothing technique is often beneficial, when we have a lot of constraints (in the above mentioned vectorial manner), since we can avoid several gradient evaluations for the constraint functions here. This leads to a faster iteration time.</p></div>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @time global v4 = exact_penalty_method(
    	M, f, grad_f!, x0; g=g2, grad_g=grad_g2!, evaluation=InplaceEvaluation(),
        smoothing=LinearQuadraticHuber(),
    	debug=[:Iteration, :Cost, :Stop, " | ", :Change, 50, "\n"],
    );
end</code></pre>
<pre id="plutouiterminal">Initial F(x): -0.000549 |
# 50    F(x): -0.116649 | Last Change: 0.009309
# 100   F(x): -0.116647 | Last Change: 0.000335
The value of the variable (ϵ) is smaller than or equal to its threshold (1.0e-6).
The algorithm performed a step with a change (6.143906154658886e-8) less than 1.0e-6.
  0.740372 seconds (3.07 M allocations: 672.773 MiB, 8.46% gc time, 69.12% compilation time)
</pre>


<div class="markdown"><p>For the result we see the same behaviour as for the other smoothing.</p></div>

<pre class='language-julia'><code class='language-julia'>f(M, v4)</code></pre>
<pre class="code-output documenter-example-output" id="var-hash501413">-0.11664711716393839</pre>

<pre class='language-julia'><code class='language-julia'>maximum(g(M, v4))</code></pre>
<pre class="code-output documenter-example-output" id="var-hash104892">2.043690782995955e-8</pre>


```
## Comparing to the unconstraint solver
```@raw html
<div class="markdown">
<p>We can compare this to the <em>global</em> optimum on the sphere, which is the unconstraint optimisation problem; we can just use Quasi Newton.</p><p>Note that this is much faster, since every iteration of the algorithms above does a quasi-Newton call as well.</p></div>

<pre class='language-julia'><code class='language-julia'>with_terminal() do
    @time global w1 = quasi_Newton(
        M, f, grad_f!, x0; evaluation=InplaceEvaluation()
    );
end</code></pre>
<pre id="plutouiterminal">  0.215234 seconds (568.88 k allocations: 60.504 MiB, 4.14% gc time, 96.68% compilation time)
</pre>

<pre class='language-julia'><code class='language-julia'>f(M, w1)</code></pre>
<pre class="code-output documenter-example-output" id="var-hash126300">-0.1302345726206443</pre>


<div class="markdown"><p>But for sure here the constraints here are not fulfilled and we have veru positive entries in <span class="tex">$g(w_1)$</span></p></div>

<pre class='language-julia'><code class='language-julia'>maximum(g(M, w1))</code></pre>
<pre class="code-output documenter-example-output" id="var-hash765286">0.15538183977528933</pre>


```
## Literature
```@raw html
<div class="markdown">
<div class="footnote" id="footnote-BergmannHerzog2019"><p class="footnote-title">BergmannHerzog2019</p><blockquote><p>R. Bergmann, R. Herzog, <strong>Intrinsic formulation of KKT conditions and constraint qualifications on smooth manifolds</strong>, In: SIAM Journal on Optimization 29(4), pp. 2423–2444 (2019) doi: <a href="https://doi.org/10.1137/18M1181602">10.1137/18M1181602</a>, arXiv: <a href="https://arxiv.org/abs/1804.06214">1804.06214</a>.</p></blockquote></div><div class="footnote" id="footnote-LiuBoumal2020"><p class="footnote-title">LiuBoumal2020</p><blockquote><p>C. Liu, N. Boumal, <strong>Simple Algorithms for Optimization on Riemannian Manifolds with Constraints</strong>, In: Applied Mathematics &amp; Optimization 82, pp. 949–981 (2020), doi <a href="https://doi.org/10.1007/s00245-019-09564-3">10.1007/s00245-019-09564-3</a>, arXiv: <a href="https://arxiv.org/abs/1901.10000">1901.10000</a>.</p></blockquote></div></div>

<!-- PlutoStaticHTML.End -->
```
