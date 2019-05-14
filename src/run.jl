module Run

using PaddedViews
using Random
using RecursiveArrayTools

function GrabZeroLocations(matrix::Array{Float64})::Array{Bool}
        zero_locations = falses(size(matrix))
        for ind = 1:length(matrix)
                zero_locations[ind] = (matrix[ind] == 0)
        end
        return zero_locations
end

function ConvertMatrix(matrix::Array{Float64}, size::Int64)
        # subtract profit matrix from a matrix made of the max value of the profit matrix
        offset_matrix = ones(Float64,(size,size)) * maximum(matrix)
        cost_matrix = offset_matrix - matrix
        return cost_matrix
end

mutable struct Hungarian
        original_matrix::Array{Float64}
        cost_matrix::Array{Float64}
        max_rows::Int64
        max_columns::Int64
        matrix_size::Int64
        matrix::Array{Float64}
        results::Array{Tuple{Int64,Int64}}
        totalPotential::Float64

        Hungarian(m::Array{Float64}) = (
        h = new();
        h.original_matrix = m;
        h.max_rows = size(m,1);
        h.max_columns = size(m,2);
        h.matrix_size = max(h.max_rows,h.max_columns);
        h.matrix = Array(PaddedView(0, m, (Base.OneTo(h.matrix_size), Base.OneTo(h.matrix_size))));
        h.cost_matrix = ConvertMatrix(h.matrix, h.matrix_size);
        h.results = [];
        h.totalPotential = 0;
        return h;
        )::Hungarian

end

mutable struct CoverZeros
        zero_locations::Array{Bool}
        mshape::Tuple{Int64,Int64}
        choices::Array{Bool}
        marked_rows::Vector{Int64}
        marked_columns::Vector{Int64}
        covered_rows::Vector{Int64}
        covered_columns::Vector{Int64}
        matrix::Array{Float64}

        CoverZeros(m::Array{Float64}) = (
        c = new();
        c.matrix = m;
        c.zero_locations = GrabZeroLocations(m);
        c.mshape = size(m);
        c.choices = falses(c.mshape);
        c.marked_rows = Vector{Int64}();
        c.marked_columns = Vector{Int64}();
        c.covered_rows = Vector{Int64}();
        c.covered_columns = Vector{Int64}();
        return c;
        )::CoverZeros

end

function Calculate(h::Hungarian)
    result_matrix = copy(h.cost_matrix)
    # Step 1: Subtract row mins from each row.
    result_matrix = SubtractRows(result_matrix,h.matrix_size)

    # Step 2: Subtract column mins from each column
    result_matrix = SubtractColumns(result_matrix,h.matrix_size)

    # Step 3: Use minimum number of lines to cover all zeros in the matrix.

    total_covered = 0
    while total_covered < h.matrix_size
            cover_zeros = CoverZeros(result_matrix)
            _calculate(cover_zeros)
            cover_zeros.covered_rows = setdiff(collect(1:h.matrix_size),cover_zeros.marked_rows)
            cover_zeros.covered_columns = cover_zeros.marked_columns
            covered_rows = get_covered_rows(cover_zeros)
            covered_columns = get_covered_columns(cover_zeros)
            total_covered = length(covered_rows) + length(covered_columns)

        #     if the total covered rows+columns is not equal to the matrix size then adjust it by min uncovered num (m).
            if total_covered < h.matrix_size
                    result_matrix = _adjust_matrix_by_min_uncovered_num(h,result_matrix, covered_rows, covered_columns)
            end
    end

    # Step 4: Starting with the top row, work your way downwards as you make assignments.
    # Find single zeros in rows or columns.
    # Add them to final result and remove them and their associated row/column from the matrix.

    expected_results = min(h.max_columns, h.max_rows)
    zero_locations = GrabZeroLocations(result_matrix)

    while length(h.results) != expected_results
            # If number of zeros in the matrix is zero before finding all the results then an error has occurred.
            if any(x->x==true, zero_locations) == false
                    println("Unable to find results. Algorithm failed.")
                    exit()
            end
            # Find results and mark rows and columns for deletion
            matched_rows, matched_columns = _find_matches(zero_locations,h)

            # Make arbitrary selection
            total_matched = length(matched_rows) + length(matched_columns)
            if total_matched == 0
                    matched_rows, matched_columns = _select_arbitrary_match(zero_locations)
            end

            for row in matched_rows
                    for col = 1:length(zero_locations[row,:])
                            zero_locations[row,col] = false
                    end
            end

            for col in matched_columns
                    for row = 1:length(zero_locations[:,col])
                            zero_locations[row,col] = false
                    end
            end

            _set_results(zip(matched_rows,matched_columns),h)

    end

    # Calculate total potential
    val = 0
    for value in h.results
            val += h.original_matrix[value[1],value[2]]
            h.totalPotential = val
    end


end

function get_results(h::Hungarian)
        """Get results after calculation."""
        return h.results
end

function get_total_potential(h::Hungarian)
        """Returns expected value after calculation."""
        return h.totalPotential
end

function _set_results(result_lists::Base.Iterators.Zip, h::Hungarian)
        """Set results during calculation."""
        # Check if results values are out of bound from input matrix (because of matrix being padded).
        # Add results to results list.
        for result in result_lists
                row, column = result
                if row <= h.max_rows && column <= h.max_columns
                        new_result = (Int64(row), Int64(column))
                        push!(h.results,new_result)
                end
        end
end

function _select_arbitrary_match(zero_locations::Array{Bool})
        """Selects row column combination with minimum number of zeros in it."""
        # Count number of zeros in row and column combinations
        rows, columns = WhereAll(zero_locations)
        zero_count = []
        for index = 1:length(rows)
                total_zeros = sum(zero_locations[rows[index],:]) + sum(zero_locations[:,columns[index]])
                push!(zero_count,total_zeros)
        end

        # Get the row column combination with the minimum number of zeros.
        indices = findall(x->x==minimum(zero_count), zero_count)[1]
        row = [rows[indices]]
        column = [columns[indices]]

        return row, column


end

function WhereAll(m::Array{Bool})
        rows = Int64[]
        cols = Int64[]
        for row = 1:size(m)[1]
                for col = 1:size(m)[2]
                        if m[row,col] == true
                                push!(rows,row)
                                push!(cols,col)
                        end
                end
        end
        return rows,cols
end

function _find_matches(zero_locations::Array{Bool},h::Hungarian)
        """Returns rows and columns with matches in them."""
        marked_rows = Int64[];
        marked_columns = Int64[];
        # Mark rows and columns with matches
        # Iterate over rows
        for index = 1:size(zero_locations)[1]
                row_index = [index]
                if sum(zero_locations[index,:]) == 1
                        column_index = Where(zero_locations[index,:])
                        marked_rows, marked_columns = _mark_rows_and_columns(marked_rows,marked_columns,row_index,column_index)
                end
        end

        for index = 1:size(zero_locations)[1]
                column_index = [index]
                if sum(zero_locations[:,index]) == 1
                        row_index = Where(zero_locations[:,index])
                        marked_rows, marked_columns = _mark_rows_and_columns(marked_rows,marked_columns,row_index,column_index)
                end
        end

        return marked_rows, marked_columns
end

function _mark_rows_and_columns(marked_rows::Array{Int64},marked_columns::Array{Int64},row_index::Array{Int64},column_index::Array{Int64})
        """Check if column or row is marked. If not marked then mark it."""
        new_marked_rows = marked_rows
        new_marked_columns = marked_columns
        if (any(x->x==true, Equalizer(marked_rows,row_index)) == false) && (any(x->x==true, Equalizer(marked_columns,column_index)) == false)
                splice!(marked_rows,length(marked_rows)+1:length(marked_rows),row_index)
                new_marked_rows = marked_rows
                splice!(marked_columns,length(marked_columns)+1:length(marked_columns),column_index)
                new_marked_columns = marked_columns
        end
        return new_marked_rows,new_marked_columns
end

function Equalizer(a::Array{Int64},b::Array{Int64})::Array{Bool}
        temp = Bool[]
        for val in a
                for val2 in b
                        push!(temp,val == val2)
                end
        end
        return temp
end

function _adjust_matrix_by_min_uncovered_num(h::Hungarian,result_matrix::Array{Float64}, covered_rows::Array{Int64}, covered_columns::Array{Int64})
        """Subtract m from every uncovered number and add m to every element covered with two lines."""
        # Calculate minimum uncovered number (m)
        elements = []
        for row_index = 1:h.matrix_size
                if any(x->x==row_index, covered_rows) == false
                        for index = 1:length(result_matrix[row_index,:])
                                if any(x->x==index, covered_columns) == false
                                        push!(elements,result_matrix[row_index,index])
                                end

                        end
                end
        end
        min_uncovered_num = minimum(elements)

        # Add m to every covered element
        adjusted_matrix = result_matrix

        for row in covered_rows
                for col = 1:length(adjusted_matrix[row,:])
                        adjusted_matrix[row,col] += min_uncovered_num
                end
        end

        for column in covered_columns
                for row = 1:length(adjusted_matrix[:,column])
                        adjusted_matrix[row,column] += min_uncovered_num
                end
        end

        # Subtract m from every element
        m_matrix = ones(Int64,(size(adjusted_matrix))) * min_uncovered_num
        adjusted_matrix -= m_matrix
        return adjusted_matrix

end



function _calculate(c::CoverZeros)
        while true
                c.marked_rows = Int64[]
                c.marked_columns = Int64[]

                # Mark all rows in which no choice has been made.
                for row = 1:c.mshape[1]
                        if any(x->x==true, c.choices[row,:]) == false
                                push!(c.marked_rows,row)
                        end
                end

                # If no marked rows then finish.
                if isempty(c.marked_rows)
                        return true
                end

                # Mark all columns not already marked which have zeros in marked rows.
                num_marked_columns = _mark_new_columns_with_zeros_in_marked_rows(c)

                # If no new marked columns then finish.
                if num_marked_columns == 0
                        return true
                end
                # While there is some choice in every marked column.
                while _choice_in_all_marked_columns(c)
                        # Some Choice in every marked column.

                        # Mark all rows not already marked which have choices in marked columns.
                        num_marked_rows = _mark_new_rows_with_choices_in_marked_columns(c)

                        # If no new marks then Finish.
                        if num_marked_rows == 0
                                return true
                        end

                        # Mark all columns not already marked which have zeros in marked rows.
                        num_marked_columns = _mark_new_columns_with_zeros_in_marked_rows(c)

                        # If no new marked columns then finish.
                        if num_marked_columns == 0
                                return true
                        end

                end
                # No choice in one or more marked columns.
                # Find a marked column that does not have a choice.
                choice_column_index = _find_marked_column_without_choice(c)
                while choice_column_index != nothing
                        # Find a zero in the column indexed that does not have a row with a choice.
                        choice_row_index = _find_row_without_choice(choice_column_index,c)

                        # Check if an available row was found.
                        new_choice_column_index = nothing
                        if choice_row_index == nothing
                                # Find a good row to accomodate swap. Find its column pair.
                                choice_row_index, new_choice_column_index = _find_best_choice_row_and_new_column(choice_column_index,c)

                                # Delete old choice.
                                c.choices[choice_row_index,new_choice_column_index] = false
                        end
                        # Set zero to choice.
                        c.choices[choice_row_index,choice_column_index] = true

                        # Loop again if choice is added to a row with a choice already in it.
                        choice_column_index = new_choice_column_index
                end
        end




end

function _mark_new_columns_with_zeros_in_marked_rows(c::CoverZeros)
        """Mark all columns not already marked which have zeros in marked rows."""
        num_marked_columns = 0
        for col = 1:c.mshape[1]
                if any(x->x==col, c.marked_columns) == false
                        if any(x->x==true, c.zero_locations[:,col])
                                row_indices = Where(c.zero_locations[:,col])
                                zeros_in_marked_rows = !isempty(intersect(c.marked_rows,row_indices))
                                if zeros_in_marked_rows
                                        push!(c.marked_columns,col)
                                        num_marked_columns += 1
                                end
                        end
                end
        end
        return num_marked_columns
end

function _choice_in_all_marked_columns(c::CoverZeros)
        """Return Boolean True if there is a choice in all marked columns. Returns boolean False otherwise."""
        for column_index in c.marked_columns
                if any(x->x==true, c.choices[:,column_index]) == false
                        return false
                end
        end
        return true

end

function _mark_new_rows_with_choices_in_marked_columns(c::CoverZeros)
        """Mark all rows not already marked which have choices in marked columns."""
        num_marked_rows = 0
        for row = 1:c.mshape[1]
                if any(x->x==row, c.marked_rows) == false
                        if any(x->x==true, c.choices[row,:])
                                column_index = Where(c.choices[row,:])
                                if column_index[1] in c.marked_columns
                                        push!(c.marked_rows,row)
                                        num_marked_rows += 1
                                end
                        end

                end
        end
        return num_marked_rows

end

function _find_marked_column_without_choice(c::CoverZeros)
        """Find a marked column that does not have a choice."""
        for column_index in c.marked_columns
                if any(x->x==true, c.choices[:,column_index]) == false
                        return column_index
                end
        end
        println("Could not find a column without a choice. Failed to cover matrix zeros. Algorithm has failed.")
        exit()
end

function _find_row_without_choice(choice_column_index::Int64,c::CoverZeros)
        """Find a row without a choice in it for the column indexed. If a row does not exist then return None."""
        row_indices = Where(c.zero_locations[:,choice_column_index])
        for row_index in row_indices
                if any(x->x==true, c.choices[row_index,:]) == false
                        return row_index
                end
        end
        # All rows have choices. Return None.
        return nothing
end

function _find_best_choice_row_and_new_column(choice_column_index::Int64, c::CoverZeros)
        """
        Find a row index to use for the choice so that the column that needs to be changed is optimal.
        Return a random row and column if unable to find an optimal selection.
        """
        row_indices = Where(c.zero_locations[:,choice_column_index])
        for row_index in row_indices
                column_indices = Where(c.choices[row_index,:])
                column_index = column_indices[1]
                if _find_row_without_choice(column_index,c) != nothing
                        return row_index, column_index
                end
        end

        # Cannot find optimal row and column. Return a random row and column.
        shuffle!(row_indices)
        column_index = Where(c.choices[row_indices[1],:])
        return row_indices[1], column_index[1]
end

function SubtractRows(matrix::Array{Float64},matrix_size::Int64)::Array{Float64}
        for row = 1:matrix_size
                row_min = minimum(matrix[row,:])
                for col = 1:matrix_size
                        matrix[row,col] -= row_min
                end
        end
        return matrix
end

function SubtractColumns(matrix::Array{Float64}, matrix_size::Int64)::Array{Float64}
        for col = 1:matrix_size
                col_min = minimum(matrix[:,col])
                for row = 1:matrix_size
                        matrix[row,col] -= col_min
                end
        end
        return matrix
end

function get_covered_rows(c::CoverZeros)
        """Return list of covered rows."""
        return c.covered_rows
end

function get_covered_columns(c::CoverZeros)
        """Return list of covered columns."""
        return c.covered_columns
end

function Where(m::Array{Bool})::Array{Int64}
        temp_list = Int64[]
        for ind = 1:length(m)
                if m[ind] == true
                        push!(temp_list,ind)
                end
        end
        return temp_list
end

function FixNegatives(m::Array{Float64})
        min_value = minimum(m)
        if min_value < 0
                count = 1
                for value in m
                        m[count] += abs(min_value)
                        count+=1
                end
        end
end


end  # module Run
