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
    # Replace hyphens with n-dashes when they indicate a range of dates
    # This allows browsers to properly insert newlines on small screen sizes
    # For some reason this has to be done *after* pandoc runs or else pandoc
    # will insert a newline in month (e.g. 04 => 0\n4)
    md = read(h, String)
    md = replace(md, r"(?<=\d)-(?=\d)" => "–")
    md = replace(md, r"(?<=day)-" => "–")
    write(h, md)
    nothing
end
