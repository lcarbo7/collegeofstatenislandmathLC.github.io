# run with julia download-academic-calendar.jl
using pandoc_jll
function (@main)(args...)
    url = "https://www.cuny.edu/academics/academic-calendars/"
    f = tempname() * ".html"
    g = tempname() * ".html"
    download(url, f)

    flag = false
    open(g, "w") do io
        for r ∈ readlines(f)
            @show r
            contains(r, "<table") && (flag = true)
            r = replace(r, r"</?span[^>]*>" => "")
            flag && println(io, r)
            contains(r, "</table") && (flag = false)
        end
    end
    h = "academic-calendar.qmd"
    pandoc() do bin
        run(`$bin -f html -t markdown $g -o $h`)
    end
    nothing
end
