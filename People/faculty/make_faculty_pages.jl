## This can make the faculty pages
## run through
## julia make_faculty_pages.jl

using CSV, DataFrames
using Mustache
# NM,NOTE,OFFICE,PHONE,RANK,URL,EMAIL,IMG,INTERESTS,BIO
tpl = mt"""
---
title: {{{:NM}}}
image: {{#:IMG}}{{{:IMG}}}{{/:IMG}}{{^:IMG}}./default.png{{/:IMG}}
image-alt: {{{:NM}}}
description: {{:RANK}}
lastname: {{{:LASTNAME}}}
about:
  template: solana
  image-width: 350px
---


{{{:INTERESTS}}}

## Contacts

<i class="bi bi-door-open"></i> **Office** | {{#:OFFICE}}{{{:OFFICE}}}{{/:OFFICE}} <br/>
<i class="bi bi-telephone"></i> **Telephone** | {{{:PHONE}}} <br/>
<i class="bi bi-mailbox"></i> **Email** | `{{{:EMAIL}}}` <br/>
{{#:URL}}<i class="bi bi-x-diamond"></i> **Website**  | [{{{:URL}}}]({{{:URL}}}){{/:URL}} <br/>

{{#:bio}}
## Biography

{{{:bio}}}
{{/:bio}}

"""

d = CSV.read("faculty.csv", DataFrame)
bios = include("faculty-bios.jl")
dd = DataFrame((NM=k, bio=v) for (k, v) ∈ bios)
d = leftjoin(d, dd, on=:NM)
d.LASTNAME .= ""

for r ∈ eachrow(d)
    first, last = split(r.NM, " ")
    r.LASTNAME = last
    fname = "$last-$first.qmd"
    fname = replace(fname, "'" => "")

    open(fname, "w") do io
        Mustache.render(io, tpl; r...)
    end
end
