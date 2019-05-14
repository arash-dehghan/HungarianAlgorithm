using PaddedViews
using Random
using RecursiveArrayTools

include("../src/run.jl")

# 6 x 6 profit matrix with no negative values
profit_matrix = [
[62.32, 75.12, 80.10, 93.34, 95.89, 97.23],
[75.12, 80.16, 82.98, 85.26, 71.67, 97.35],
[80.19, 75.23, 81.52, 98.36, 90.45, 97.12],
[78.41, 82.17, 84.82, 80.82, 50.24, 98.06],
[90.37, 85.13, 85.97, 80.91, 85.02, 99.68],
[65.86, 75.08, 80.04, 75.09, 68.67, 96.12]]

# 6 x 5 profit matrix with negative values
# profit_matrix = [
# [-62.32, 75.12, 80.10, 93.34, 95.89],
# [75.12, 80.16, 82.98, 85.26, 71.67],
# [80.19, 75.23, 81.52, 98.36, 90.45],
# [78.41, 82.17, 84.82, 80.82, 50.24],
# [90.37, 85.13, 85.97, 80.91, 85.02],
# [65.86, 75.08, 80.04, 75.09, 68.67]]


VA = VectorOfArray(profit_matrix)
arr = convert(Array,VA)

Run.FixNegatives(arr)
h = Run.Hungarian(arr)
@time Run.Calculate(h)

println("Calculated value: \$$(round(Run.get_total_potential(h),digits = 2))")
println("Results: $(Run.get_results(h))")
println("--------------------------------------------------")
