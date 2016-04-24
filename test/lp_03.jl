# Test get/set objective coefficients in LP

using Xpress
using Base.Test


# original model
#
#   maximize  2x + 2y
#
#	s.t. 0.2 <= x, y <= 1
#         

model = xpress_model(
	name="lp_03",
	sense=:maximize,
	f=[2.0, 2.0], 
	lb=[0.2, 0.2],
	ub=[1.0, 1.0])

println(model)

lb_ = lowerbounds(model)
ub_ = upperbounds(model)
c_ = objcoeffs(model)

@test lb_ == [0.2, 0.2]
@test ub_ == [1.0, 1.0]
@test c_ == [2.0, 2.0]

optimize(model)

println()
println("soln = $(get_solution(model))")
println("objv = $(get_objval(model))")


# change objective (warm start)
#
#	maximize x - y
#
#	s.t. 0.2 <= x, y <= 1
#

set_objcoeffs!(model, [1, -1])
#update_model!(model)

c_ = objcoeffs(model)
@test c_ == [1.0, -1.0]

optimize(model)

println()
println("soln = $(get_solution(model))")
println("objv = $(get_objval(model))")

gc()
