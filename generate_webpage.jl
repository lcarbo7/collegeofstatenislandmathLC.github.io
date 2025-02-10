#!/bin/bash
#=
#exec julia --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@"
export JULIA_DEPOT_PATH="/home/NewWebsite/.julia"
exec julia --project=/home/NewWebsite/ --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@"
=#

# export JULIA_DEPOT_PATH in shell instead of hardcoding this; makes the julia script portable
# DEPOT_PATH[1] = "/home/NewWebsite/.julia"

using ArgParse

## run as script: generate_webpage.jl --force=true --python=true
function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--force", "-f"
        help = "Force creation of all files"
        default = false
        "--python", "-p"
        help = "Run python script of MVJ to populate courses page"
        default = true
        "--out", "-o"
        help = "Output directory (for local builds)"
        default = "/home/httpd/htdocs/"
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    force = parsed_args["force"] == "true" ? true : false
    call_python = parsed_args["python"] == "false" ? false : true
    outdir = parsed_args["out"]

    global sitedir = outdir

    generate_website(; force=force, python=call_python)
end


# Generate webpage

basedir = @__DIR__
basedir *= "/"
datadir = basedir * "data/"
editdir = joinpath(basedir, "edit_these")
templatedir = basedir * "_templates/"
#sitedir = joinpath(basedir, "_site") * "/"
#baseurl = "https://www.math.csi.cuny.edu/_newsiste"

BANNER = "./images/banners/hintoncubes.jpg" #"./images/banners/math-art.png"
BANNER_ALT = "CSI Math (Hinton's illustration of the tessaract)"

## XXXon Gauss these get changed
sitedir = "/home/httpd/htdocs/" # gets updated in main()
baseurl = "https://www.math.csi.cuny.edu/"


## ----

ABHIJIT_LOGO = """<i class="bi bi-calculator"></i>""" # add in <img src="..." alt="..."> here
TOBY_FONT = "raleway" # or "raleway"  or "Neuton" or what ever, but that might need some support

no_calendar_items = 5

using Mustache
using DelimitedFiles
using CSV
using DataFrames
using Dates
using Weave
using JSON3

include(joinpath(basedir, "ashtml.jl"))

include(joinpath(editdir, "math_dept_blurb.jl"))
include(joinpath(editdir, "navbar_links.jl"))
include(joinpath(editdir, "quick_links.jl"))
include(joinpath(editdir, "news.jl"))
FACULTY_CSV = joinpath(editdir, "faculty.csv")
STAFF_CSV = joinpath(editdir, "staff.csv")

#include(joinpath(basedir, "edit_these", "carousel_items.jl"))
## -----

## functions to generate pieces or pages
### Carousel
function carousel()

    carousel_tpl = Mustache.template_from_file(joinpath(templatedir, "carousel.tpl"))
    Mustache.render(carousel_tpl;
        CAROUSEL_BUTTONS=carousel_buttons(),
        CAROUSEL_ITEMS=make_carousel_items())
end

function carousel_buttons(; kwargs...) # pass in IO buffer
    n = length(carousel_items)
    DataFrame(i=1:n, j=0:(n-1))
end

function make_carousel_items(; kwargs...)
    # CAROUSEL_ITEMS needs ACTIVE ("active", ""), IMG, HEADLINE, TEXT, ALT
    d = DataFrame(carousel_items)
    d.TEXT = ashtml.(d.TEXT)
    d.ACTIVE = [i == 1 ? " active" : "" for i ∈ 1:size(d, 1)]
    d
end


function banner()
    Mustache.render(banner_tpl,
        TEXT=" <h1>The Department of Mathematics</h1>",
        IMG=BANNER,
        ALT=BANNER_ALT)
end


function breadcrumbs(dir, file)

    aria_current = """ aria-current="page" """
    active = " active"


    ext = file_extension(file)
    bfile = strip_extension(file)
    fs = vcat(filter(!isempty, split(dir, "/"))..., bfile)
    fs[end] == "index" && (pop!(fs))

    n = length(fs)
    d = DataFrame(
        URL=vcat("/", ["/" * join(fs[1:i], "/") for i ∈ 1:length(fs)-1], ""),
        ALT=["CSI Math", "Link to directory " .* fs[1:end-1]..., ""],
        CURRENT=[i == n ? aria_current : "" for i ∈ 0:n],
        ACTIVE=[i == n ? active : "" for i ∈ 0:n],
        NM=vcat("CSI Math", collect(fs))
    )
    d
end

# blurbs with image + paragraph
function featurettes(; kwargs...)
    # create vector with each featurette item:
    # in
    d = DataFrame(featurettes_list)
    d[!, :TEXT] = ashtml.(d[!, :TEXT])

    d.ORDER1 = [iseven(i) ? "" : "order-md-1" for i ∈ 1:size(d, 1)] # toggle left right
    d.ORDER2 = [iseven(i) ? "" : "order-md-2" for i ∈ 1:size(d, 1)]
    d
end


## Focus: boxes on bottom
## Logins
function focus1(; kwargs...)
    Mustache.render(link_tpl; TITLE="Quick links", LINKS=quick_Links)
end

## Newsy?
function focus2(; kwargs...)
    d = make_news()
    if size(d, 1) > 0
        Mustache.render(link_tpl; TITLE="Recent news", LINKS=d)
    else
        "No recent news"
    end
end

## Calendar (People don't like here)
function focus3(; kwargs...)
    d = make_calendar()[1]
    d′ = size(d, 1) > 0 ? d : DataFrame(DATE="", EVENT="No upcoming events")
    Mustache.render(calendar_tpl_short; CAL=d′)
end

# create :FOCUS_ITEMS text
function focus_items(; kwargs...)
    FOCUS_ITEMS = [(FOCUS_ITEM=focus2(),),
        (FOCUS_ITEM=focus3(),),]
    # (FOCUS_ITEM=focus3(),)] <-- no calendar
end


function news_names(nm)
    nm = replace(nm, "_" => " ")
    nm = replace(nm, "-" => " ")
    uppercasefirst(nm)
end

# News files are in a special format with the first line
# have a header in markdown
# in the file name _ and - are replaced with a space
function make_news()
    # add links to 5 most recent news items in past year
    newsdir = joinpath(datadir, "News")
    nms = readdir(newsdir, join=true)
    nms = filter(isfile, nms)
    mtimes = mtime.(nms)
    nms = basename.(nms)

    d = DataFrame(NM=news_names.(strip_extension.(nms)),
        mtime=mtimes)
    d.URL = fname_to_x.(nms, "News", baseurl)
    d.ALT = d.NM
    d = filter(:mtime => mt -> (time() - mt < 60 * 60 * 24 * 365), d)
    d[:, :BI] .= "newspaper"
    sort!(d, :mtime, rev=true)
    #d = d[sortperm(d.mtime, rev=true), :]
    d = d[1:min(5, size(d, 1)), :]
    d
end


function make_calendar()
    d = CSV.read(joinpath(editdir, "calendar.csv"), DataFrame)
    d = d[completecases(d), :]
    d.DATE = Date.(d[:, 1], d[:, 2], d[:, 3])
    d.EVENT = d[:, 4]
    d = filter(:DATE => x -> x > today(), d)
    d = d[sortperm(d.DATE), :]

    # we do two things: make a 5-entry page; make a calendar
    d[1:min(no_calendar_items, size(d, 1)), :], d
end

function footer()
    """
<strong>Department of Mathematics</strong><br/>
<i class="bi bi-building"></i>
<a href="https://www.csi.cuny.edu">College of Staten Island</a> /
<a href="https://www.cuny.edu">City University of New York</a><br/>
<i class="bi bi-geo"></i>1S-215; 2800 Victory Boulevard, Staten Island, NY 10314<br/>
<i class="bi bi-telephone"></i> (718) 982-3600<br/>
<i class="bi bi-envelope"></i> <a href="mailto:mathematics@csi.cuny.edu">mathematics@csi.cuny.edu</a>
"""
end

## --- utils

## --- pagemakers
function landing_page(io::IO; kwargs...)
    landing_tpl = Mustache.template_from_file(joinpath(templatedir, "new_landing_page.tpl"))

    Mustache.render(io, landing_tpl;
        TITLE="Department of Mathematics at CSI",
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        NAVBAR=navbar_links,
        #                    CAROUSEL = carousel(),
        BANNER=banner(),
        COURSE_LINKS=course_links,
        QUICK_LINKS=quick_links,
        NEWS=ashtml(NEWS),
        FEATURETTES=featurettes(),
        FOCUS_ITEMS=focus_items(),
        FOOTER=footer())

end


function people_page(io::IO; kwargs...)
    FACULTY = CSV.read(FACULTY_CSV, DataFrame)
    STAFF = CSV.read(STAFF_CSV, DataFrame)

    FACULTY.INTERESTS = (ashtml ∘ markdown_parse).(FACULTY.INTERESTS)

    FACULTY.ORDER1 = [iseven(i) ? "" : "order-md-1" for i ∈ 1:size(FACULTY, 1)] # toggle left right
    FACULTY.ORDER2 = [iseven(i) ? "" : "order-md-2" for i ∈ 1:size(FACULTY, 1)] # toggle left right

    STAFF.ORDER1 = [iseven(i) ? "" : "order-md-1" for i ∈ 1:size(STAFF, 1)] # toggle left right
    STAFF.ORDER2 = [iseven(i) ? "" : "order-md-2" for i ∈ 1:size(STAFF, 1)] # toggle left right

    BODY = Mustache.render(people_tpl; FACULTY=FACULTY, STAFF=STAFF)
    SIDEBAR = Mustache.render(people_sidebar_tpl; FACULTY=FACULTY, STAFF=STAFF)

    Mustache.render(io, Mustache.template_from_file(joinpath(templatedir, "people_page.tpl"));
        TITLE="Faculty and Staff",
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        NAVBAR=navbar_links,
        SIDEBAR=SIDEBAR,
        BODY=BODY,
        FOOTER=footer()
    )

end


function syllabus_page(io::IO; kwargs...)


    sdir = "Undergraduate/Courses/Syllabi/"
    crsdir = joinpath(datadir, sdir)
    nms = readdir(crsdir)
    nms = filter(x -> startswith(x, r"MTH"), nms)


    d = DataFrame(; nms)
    d = transform(d, :nms => ByRow(x -> "$(x[1:3]) $(x[4:6])") => :name)
    d = transform(d, [:nms] => ByRow(x -> joinpath("/" * sdir, x)) => :url)

    tpl = mt"""
<h1> Departmental syllabi</h1>

<p>
This directory contains syllabi for many of the math department's classes. It may not contain the most current version. Please check with your professor to be sure.
</p>

<ul>
{{#:D}}
<li> <i class="file-earmark-pdf"> <A href={{{:url}}} alt="Syllabus for {{{:name}}}">{{{:name}}}</a> </li>
{{/:D}}
</ul>
"""


    Mustache.render(io, Mustache.template_from_file(joinpath(templatedir, "basic_page.tpl"));
        TITLE="Departmental Syllabuses",
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        NAVBAR=navbar_links,
        BODY=Mustache.render(tpl; D=d),
        FOOTER=footer()
    )

end



function calendar_page(io::IO; kwargs...)
    ## do this if calendar has new data...
    csv = joinpath(basedir, "edit_these", "calendar.csv")
    html = joinpath(sitedir, "calendar.html")
    ##    isfile(html) && (mtime(html) > mtime(csv)) && return
    calendar = make_calendar()[2]
    CALENDAR = Mustache.render(calendar_tpl, CALENDAR=calendar)
    page_tpl = Mustache.template_from_file(joinpath(templatedir, "basic_page.tpl"))
    Mustache.render(io, page_tpl;
        TITLE="Calendar",
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        NAVBAR=navbar_links,
        NOSIDEBAR=true,
        BODY=CALENDAR,
        FOOTER=footer()
    )
end


function crs_num(x)
    tparts = split(x, r"\s+")
    num = tryparse(Int, tparts[3])
    isnothing(num) ? 1000 : num
end

function sortD(d)
    d = transform(d, :title => ByRow(crs_num) => :crs_num)
    d = sort(d, :crs_num)
    d
end


function cunyfirst_page(io::IO; kwargs...)

    if mtime(tempdir()) - mtime(joinpath(@__DIR__, "course_list.json")) > 10 * 24 * 60 * 60
        try
            run("python3 " * joinpath(@__DIR__, "cf_scrape.py"))
        catch err
        end
    end

    m, y = month(now()), rem(year(now()), 2000)
    (M, sema) = m in (10, 11, 12, 1, 2, 3) ? (2, "Spring") : (9, "Fall")

    json_string = read(joinpath(@__DIR__, "course_list.json"), String)
    json = JSON3.read(json_string)
    L = Any[]
    for (i, (k, v)) in enumerate(json)

        year = parse(Int, string(k)[2:3])
        sem0 = parse(Int, string(k)[4])
        sem = sem0 == 9 ? "Fall" : sem0 == 2 ? "Spring" : "Summer"
        active = (sema == sem && y == year) ? true : false
        D = sortD(DataFrame(v[:coursedata]))
        push!(L, (; i, sem, year, active, D))
    end

    tpl = mt"""
<h1> CUNY First class listings</h1>

Please check 
<a href="https://globalsearch.cuny.edu/CFGlobalSearchTool/search.jsp">
Global Search</a> for the offical listings (this is a snapshot).

<ul class="nav nav-tabs" role="tablist">
{{#:L}}
<li class="nav-item" role="presentation">
<a class="nav-link{{#:active}} active{{/:active}}"
  id="CF-{{:i}}" 
  data-mdb-toggle="tab"
  data-bs-toggle="tab"
  href="#CF-tab-{{:i}}"
  role="tab"	
  aria-controls="CF-tab-{{:i}}"
  aria-selected={{#:active}}"true"{{/:active}}{{^:active}}"false"{{/:active}}
  >{{:sem}} 20{{:year}}</a>
</li>
{{/:L}}
</ul>

<div class="tab-content">
{{#:L}}
<div class="tab-pane fade {{#:active}}show active{{/:active}}"
    id="CF-tab-{{:i}}"
    role="tabpanel"
    aria-labelledby="CF-{{:i}}">

<table>
<tr>
<th>Title</th>
<th>Instructor</th>
<th>Meets</th>
<th>Room</th>
<th>Section</th>
<th>Mode</th>
</tr>

{{#:D}}
<tr>
<td>{{{:title}}}</td>
<td>{{{:instructor}}}</td>
<td>{{{:meets}}}</td>
<td>{{{:room}}}</td>
<td>{{{:section}}}</td>
<td>{{{:mode}}}</td>
</tr>
{{/:D}}
</table>
</div>

{{/:L}}
</div>

"""

    Mustache.render(io, Mustache.template_from_file(joinpath(templatedir, "basic_page.tpl"));
        TITLE="CUNY First Schedule",
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        NAVBAR=navbar_links,
        BODY=Mustache.render(tpl; L=L),
        NOSIDEBAR=true,
        FOOTER=footer()
    )

end



function parse_news(f)
    a = Markdown.parse(join(readlines(f), "\n"))
    header = Markdown.plain(join(a[1].text))
end

function news_page(io::IO; kwargs...)
    NO_FILES_SHOW = 5
    page_tpl = Mustache.template_from_file(joinpath(templatedir, "basic_page.tpl"))

    newsdir = joinpath(basedir, "data", "News")
    news_files = readdir(newsdir, join=true)
    news_files = filter(isfile, news_files)

    sitenews = joinpath(sitedir, "News")
    isdir(sitenews) || mkdir(sitenews)
    newspage = joinpath(sitenews, "index.html")

    ## do this if any new news
    last_news = maximum(mtime.(news_files))
    last_news_page = isfile(newspage) ? mtime(newspage) : 0.0
    last_news_page >= last_news# && return

    ## Okay, make a page
    fs = news_files[sortperm(mtime.(news_files), rev=true)]
    fs = fs[1:min(length(fs), NO_FILES_SHOW)]

    DATE = String[]
    HEADER = String[]
    STORY = String[]
    for f ∈ fs
        cdate = Dates.unix2datetime(stat(f).mtime)
        m, d, y = monthname(cdate), day(cdate), year(cdate)
        a = Markdown.parse(join(readlines(f), "\n"))
        push!(DATE, "$m $d, $y")
        push!(HEADER, Markdown.html(a[1]))
        push!(STORY, Markdown.html(a[2:end]))
    end

    d = DataFrame(DATE=DATE, HEADER=HEADER, STORY=STORY)
    BODY = Mustache.render(news_tpl; NEWS=d)
    Mustache.render(io, page_tpl;
        TITLE="News",
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        NAVBAR=navbar_links,
        NOSIDEBAR=true,
        BODY=BODY,
        FOOTER=footer()
    )
end






# make url
function fname_to_x(f, dirs, base=baseurl)
    if _canhtml(f)
        ext = file_extension(f)
        f = replace(f, Regex("$ext\$") => ".html")
    end
    joinpath(base, dirs, f)
end

function strip_extension(f)
    ext = file_extension(f)
    replace(f, Regex("$ext\$") => "")
end
# if file is .md or .docx, ... then make .html
function adjust_extension(f)
    if _canhtml(f)
        ext = file_extension(f)
        replace(f, Regex("$ext\$") => ".html")
    else
        f
    end
end

function files_dirs(bdir, dir="", baseurl="")

    bnm = joinpath(bdir, dir)
    fds = readdir(bnm, join=true)
    dirs = filter(isdir, fds)
    fs = setdiff(fds, dirs)

    dirs = filter(!startswith(joinpath(bnm, "_")), dirs)
    dirs = filter(!startswith(joinpath(bnm, ".")), dirs)

    fs = filter(!endswith("_"), fs)
    fs = filter(!endswith("jl"), fs)

    fnames = adjust_extension.(basename.(fs))

    DIRS, FILES = DataFrame(DIR=basename.(dirs)), DataFrame(FILE=fnames)
    DIRS.URL = joinpath.(baseurl, dir, DIRS.DIR)
    FILES.URL = fname_to_x.(FILES.FILE, (dir,), baseurl)

    (FILES, DIRS)
end



function make_file_list()
    io = open("/tmp/file-list.csv", "w")
    for (root, dirs, files) ∈ walkdir(datadir)
        for file ∈ files
            occursin("_site", root) && continue
            occursin("data", root) || continue
            url = replace(root, datadir => "https://www.math.csi.cuny.edu")
            troot = replace(root, datadir => "")
            url = joinpath(url, fname_to_x(file, "", ""))
            println(io, "$troot, $file, $url")
        end
    end
end

## --------------------------------------------------

# Create a basic page.
# TODO: add in header option?
function basic_page(io::IO, fnm, FILES, DIRS, BREADCRUMBS=""; kwargs...)

    basic_tpl = Mustache.template_from_file(joinpath(templatedir, "basic_page.tpl"))

    # add a banner?
    dirnm, basenm, ext = dirname(fnm), strip_extension(basename(fnm)), file_extension(fnm)
    title = basenm
    banner, news = "", ""
    if basenm == "index"
        ## add banner
        for f ∈ readdir(dirnm)
            if "banner" == strip_extension(f)
                banner = "./$f"
                break
            end
        end
        ## adjust title
        title = last(split(dirnm, "/"))
        ## add news?
        newsfile = joinpath(dirnm, "news.md")
        if isfile(newsfile)
            news = ashtml(Val(:md), newsfile)
        end
    end

    BODY = ashtml(extension_type(fnm), fnm) # full name
    Mustache.render(io, basic_tpl;
        NAVBAR=navbar_links,
        TITLE=title,
        ABHIJIT_LOGO=ABHIJIT_LOGO,
        TOBY_FONT=TOBY_FONT,
        BANNER=banner,
        BREADCRUMBS=BREADCRUMBS,
        NEWS=news,
        FOOTER=footer(),
        BODY=BODY,
        FILES=FILES,
        DIRS=DIRS,
        NOSIDEBAR=true,#size(FILES,1) == 0 && size(DIRS,1) == 0
    )

end



# --- loop over pages ...
function generate_website(; force=true, python=true)
    python = false
    # make special pages
    # ensure subdirectories exist (esp for local builds)
    mkpath(joinpath(sitedir, "Undergraduate/Courses/Syllabi"))
    mkpath(joinpath(sitedir, "Undergraduate/Courses/CUNYFirst"))
    for (page, nm) ∈ ((landing_page, "index.html"),
        (people_page, "people.html"),
        (syllabus_page, joinpath("Undergraduate/Courses/Syllabi", "index.html")),
        (calendar_page, "calendar.html"),
        (news_page, joinpath("News", "index.html")),
        (cunyfirst_page, joinpath("Undergraduate/Courses/CUNYFirst", "index.html")),
    )
        io = IOBuffer()
        page(io)
        out = String(take!(io))
        open(joinpath(sitedir, nm), "w") do io
            print(io, out)
        end
    end

    # course list
    #    if python
    #        run("python3 " * joinpath(sitedir, "/cf_scrape.py"))
    #        cp("course_list.json", joinpath(datadir, "Undergraduate/Courses/CUNYFirst/course_list.json"), force=true)
    #    end

    # all other pages if possible, make file, else not
    function write_file(dir, file, FILES, DIRS)

        if _canhtml(file)
            _file = strip_extension(file)
            FILES = filter(:FILE => x -> strip_extension(x) != _file, FILES)
            BREADCRUMBS = breadcrumbs(dir, file)
            fnm = joinpath(datadir, dir, file)
            out = ashtml(extension_type(fnm), fnm)
            io = IOBuffer()
            basic_page(io, fnm, FILES, DIRS, BREADCRUMBS)
            out = String(take!(io))
            hfile = fname_to_x(file, dir, sitedir)
            open(hfile, "w") do io
                write(io, out)
            end
        else
            cp(joinpath(datadir, dir, file), joinpath(sitedir, dir, file), force=true, follow_symlinks=false)

        end
    end

    for (root, dirs, files) ∈ walkdir(datadir)
        dir′ = replace(root, Regex("^$datadir") => "")
        startswith(dir′, "_") && continue
        FILES, DIRS = files_dirs(datadir, dir′, baseurl)
        for dir ∈ dirs # make directories in sitedir if needed
            rdir = replace(root, Regex("^$datadir") => "")
            startswith(dir, "_") && continue  # avoid _templates, _site, say
            ndir = joinpath(sitedir, rdir, dir)
            isdir(ndir) || mkdir(ndir)
        end

        for file ∈ files
            endswith(file, "_") && continue  # filter out _files
            ext = file_extension(file)
            ext ∈ (".jl", ".csv") && continue         # filter out .jl files
            hfile = replace(file, Regex("$ext\$") => ".html")
            if force || (mtime(joinpath(root, file)) > mtime(joinpath(sitedir, dir′, hfile)))
                write_file(dir′, file, FILES, DIRS)
            end
        end
    end

end

## --- simple templates

banner_tpl = mt"""
<div class="d-block w-100">
  <div class="col d-flex justify-content-center">
    <img src="{{{:IMG}}}" alt="{{{:ALT}}}"
         class="d-block w-50" />
  </div>
  <div class="text-center">
         {{{:TEXT}}}
  </div>
</div>
<hr />
"""

link_tpl = """
{{#:TITLE}}<strong>{{{:TITLE}}}</strong>{{/:TITLE}}
<hr />
<ul class="nav nav-pills flex-column mb-auto">
{{#:LINKS}}
  <li class="nav-item">
    <a href="{{{:URL}}}"  class="nav-link text-black" aria-current="page">
      {{#:BI}}<i class="bi bi-{{{:BI}}}"></i>{{/:BI}}
      <abbrv aria-details="{{{:ALT}}}" title="{{{:ALT}}}" alt="{{{:ALT}}}">
      {{{:NM}}}
      </abbrv>
    </a>
  </li>
{{/:LINKS}}
</ul>
"""

calendar_tpl_short = mt"""
<strong>Upcoming calendar</strong>
<hr/>
<ul class="nav nav-pills flex-column mb-auto">
{{#:CAL}}
  <li class="nav-item">
  <strong>{{{:DATE}}}</strong> {{{:EVENT}}}
  </li>
  {{/:CAL}}
  {{@:CAL}}<li class="nav-item">
      <a href="/calendar.html" alt="Calendar of important dates"> more events...</a>
    </li>{{/:CAL}}
</ul>
"""

people_sidebar_tpl = mt"""
<div class="p-3">
<h2>Faculty</h2>
<ul class="list-unstyled ps-0">
{{#:FACULTY}}
<li><a href="#{{:NM}}">{{{:NM}}}</a></li>
{{/:FACULTY}}
</ul>
<h2>Staff</h2>
<ul class="list-unstyled ps-0">
{{#:STAFF}}
<li><a href="#{{:NM}}">{{{:NM}}}</a></li>
{{/:STAFF}}
</ul>
</div>
"""

people_tpl = mt"""
    <div class="container">
    <h1>People in the department</h1>
      <h2>Full-time faculty</h2>
      {{#:FACULTY}}
      <div class="row person"  id="{{{:NM}}}">
	<div class="col-md-5 {{{:ORDER2}}}">
	  {{#:IMG}}
	  <img src="{{{:IMG}}}" alt="photo of {{{:NM}}}", width="50%">
	  {{/:IMG}}
	  {{^:IMG}}
	  <i class="bi bi-people" style="font-size:4rem;"></i>
	  {{/:IMG}}
	</div>
	<div class="col-md-7 {{{:ORDER1}}}">
	  <h3>
            {{#:BIO}}<a href="{{{:BIO}}}" alt="biography of {{{:NM}}}">{{/:BIO}}
            {{{:NM}}}
	    {{#:BIO}}</a>{{/:BIO}}
          </h3>
	  {{#:NOTE}}<h4>{{:NOTE}}</h4>{{/:NOTE}}
	  {{{:RANK}}}<br/>
	  {{{:OFFICE}}}<br/>
	  {{#:PHONE}}<i class="bi bi-telephone"></i> {{{:PHONE}}}<br/>{{/:PHONE}}
	  {{#:EMAIL}}<i class="bi bi-mailbox"></i> {{{:EMAIL}}}<br/>{{/:EMAIL}}
	  {{#:URL}}<i class="bi bi-x-diamond"></i> <a href={{{:URL}}}>{{{:URL}}}</a><br/>{{/:URL}}
	  {{#:INTERESTS}}
	  <hr/>
	  {{{:INTERESTS}}}
	  {{/:INTERESTS}}
	</div>
      </div>
      {{/:FACULTY}}
    </div>

    <div class="container">
      <h2>Staff</h2>
      {{#:STAFF}}
      <div class="row person" id="{{{:NM}}}">
	<div class="col-md-5 {{{:ORDER2}}}">
	  {{#:IMG}}
	  <img src="{{{:IMG}}}" alt="photo of {{{:NM}}}">
	  {{/:IMG}}
	  {{^:IMG}}
	  <i class="bi bi-people" style="font-size:4rem;"></i>
	  {{/:IMG}}
	</div>
	<div class="col-md-7 {{{:ORDER1}}}">
	  <h3>{{{:NM}}}</h3>
	  {{{:RANK}}}<br/>
	  {{{:OFFICE}}}<br/>
	  {{#:PHONE}}<i class="bi bi-telephone"></i> {{{:PHONE}}}<br/>{{/:PHONE}}
	  {{#:EMAIL}}<i class="bi bi-mailbox"></i> <a emailto={{{:EMAIL}}}>{{{:EMAIL}}}</a><br/>{{/:EMAIL}}
	  {{#:URL}}<i class="bi bi-x-diamond"></i> <a href="{{{:URL}}}">{{{:URL}}}</a><br/>{{/:URL}}
	  {{{:INTERESTS}}}
	</div>
      </div>
      {{/:STAFF}}
    </div>
"""

calendar_tpl = mt"""
<h3>Upcoming calendar events</h3>
{{^:CALENDAR}}No upcoming events listed{{/:CALENDAR}}
{{@:CALENDAR}}
<table class="table table-striped">
  <thead>
    <tr>
      <th scope="col">Date&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th>
      <th scope="col">Event</th>
    </tr>
  </thead>
<tbody>
{{/:CALENDAR}}{{#:CALENDAR}}
    <tr>
    <th scope="row">{{{:DATE}}}</th>
      <td>{{{:EVENT}}}</td>
    </tr>
{{/:CALENDAR}}{{@:CALENDAR}}
  </tbody>
</table>
{{/:CALENDAR}}
"""

news_tpl = mt"""
<h1>Recent news</h1>
{{#:NEWS}}
<div class="card">
  <div class="card-header">{{{:DATE}}}</div>
  <div class="card-body>
    <div class="card=title">{{{:HEADER}}}</div>
    <p class="card-text">
       {{{:STORY}}}
    </p>
  </div>
</div>
{{/:NEWS}}
"""

### --- run after loading ---
main()
