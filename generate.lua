#!/usr/bin/env lua

local lfs = require("lfs")

local root_dir

if arg[1] == "gobolinux" then
   root_dir = "https://gobolinux.org"
elseif arg[1] == "local" then
   root_dir = lfs.currentdir().."/output"
else
   print("Usage:")
   print("   " .. arg[0] .. " gobolinux")
   print("      to generate the version to upload at the website")
   print("   " .. arg[0] .. " local")
   print("      to generate a version to view locally")
   os.exit(1)
end

local verbose = true

local all_ok = true

local function unindent(txt)
   return txt:gsub("^%s*", ""):gsub("\n%s*", "\n"):gsub("%s$", "")
end

local templates = {
   content_hr = unindent([[
      </div></div>
      <div class="spacer"></div>
      <div class="content_wrap">
      <div class="content_page main_column">
   ]])
}

local special_formatters = {

   -- Add some extra divs inside pages
   ["page"] = function(page)

      local h1_count = 0
   
      local first_content_block = unindent([[
         <div id="down_arrow"><div id="down_arrow_1"></div><div id="down_arrow_2"><canvas id="down_arrow_canvas"></canvas></div><div id="down_arrow_3"></div></div>
         <div class="content_wrap" id="first_content_block">
         <div class="content_page main_column">
      ]])
   
      local function make_top_title(title)
         h1_count = h1_count + 1
         return unindent([[
            <div class="content_title">
            <h1>]]..title..[[</h1>
            </div>
         ]]..first_content_block)
      end
   
      page = page:gsub("<h1>([^<]*)</h1>", make_top_title)
      
      if not page:match("<h1>") then
         page = page:gsub("<h2>([^<]*)</h2>", make_top_title, 1)
      end
   
      page = page:gsub("<hr/?>", function()
         return templates.content_hr
      end)
      page = page
      return page
   end

}

local apply_template

-- Template syntax:
-- <<@path/file>> Apply template in file `path/file`
-- <<#tagname>> Apply template in file specified in tag `tagname`
-- <<!tagname>> Apply template whose text is in tag `tagname`
-- <<tagname>> Insert text verbatim from tag `tagname`
local function apply_template_text(template, tags, lang)
   template = template:gsub("<<@([^>]*)>>", function(filename)
      return apply_template(filename, tags, lang)
   end)

   template = template:gsub("<<#([^>]*)>>", function(tag_name)
      local output = apply_template(tags[tag_name], tags, lang)
      if special_formatters[tag_name] then
         return special_formatters[tag_name](output)
      end
      return output
   end)

   template = template:gsub("<<!([^>]*)>>", function(tag_name)
      local output = apply_template_text(tags[tag_name], tags, lang)
      return output
   end)

   template = template:gsub("<<([^>]*)>>", function(varname)
      return tags[varname]
   end)

   -- Fix PHP-style links
   template = template:gsub("<a href=\"%?page=([^\"]*)\">", function(page)
      return "<a href=\""..tags.root.."/"..page..".html\">"
   end)
   
   return template 
end

apply_template = function(filename, tags, lang)
   if filename == "" then
      return ""
   end

   tags.root = root_dir
   tags.lang = root_dir.."/"..((lang == "en_US") and "" or lang)

   local fd
   fd = io.open("lang/"..lang.."/"..filename)
   if not fd then
      fd = io.open(filename)
   end
   if not fd then
      io.stderr:write("Failed opening "..filename.."\n")
      all_ok = false
      os.exit(1)
      return ""
   end
   local template = fd:read("*a")
   
   return apply_template_text(template, tags, lang)
end

local function add_meta_tags(page)
   local first_image = page:match("<img [^>]*social_thumbnail[^>]*>")
   if first_image then
      first_image = first_image:match("<img [^>]*src=\"([^\"]+)\"[^>]*>")
   else
      first_image = page:match("<img [^>]*src=\"([^\"]+)\"[^>]*>")
   end
   local first_header = page:match("<h1>([^<]+)</h1>") or page:match("<h2>([^<]+)</h2>")
   if first_image then
      page = page:gsub("<title>", unindent([[
         <meta property="og:image" content="]]..first_image..[[" />
         <title>]]), 1)
   end
   if first_header then
      first_header = first_header:gsub("\n*", "")
      page = page:gsub("<title>", unindent([[
         <meta property="og:title" content="]]..first_header..[[" />
         <title>]]), 1)
   end
   return page
end

local function render_with(page_name, template, src_dir, dst_dir, lang, extra_tags)
   io.stdout:write(page_name.." -> ")
   local tags = {
      page = src_dir.."/"..page_name,
      current_year = os.date("%Y"),
   }
   if extra_tags then
      setmetatable(tags, { __index = extra_tags })
   end
   local rendered = apply_template(template, tags, lang)
   rendered = add_meta_tags(rendered)
   local output_filename = dst_dir.."/"..(page_name:gsub("%.[^%.]*$", ""))..".html"
   os.execute("mkdir -p "..dst_dir)
   local fd = io.open(output_filename, "w")
   fd:write(rendered)
   fd:close()
   print(output_filename)
end

os.execute("rm -rf output")

local function process_pages(dir, out_dir, lang)
   for name in lfs.dir(dir) do
      if name ~= "." and name ~= ".." then
         local file_type = lfs.attributes(dir.."/"..name, "mode")
         if file_type == "file" then
            render_with(name, "templates/page.yats", dir, out_dir, lang)
         elseif file_type == "directory" then
            process_pages(dir.."/"..name, out_dir.."/"..name, lang)
         end
      end
   end
end

local function process_news(dir, out_dir, lang)
   local news = loadfile(dir .. "/news.lua")()
   local max_id = #news
   local news_posts = {}
   local function older_newer(tags, id, min, max, older_link, newer_link)
      tags.older_news_link = id > min and older_link or ""
      tags.newer_news_link = id < max and newer_link or ""
      tags.older_news = id > min and "strings/older_news" or ""
      tags.newer_news = id < max and "strings/newer_news" or ""
   end
   for id, entry in ipairs(news) do
      local tags = {
         title = entry.title,
         body = entry.body,
         date = entry.date,
         permalink = id..".html",
      }
      older_newer(tags, id, 1, max_id, (string.format("%d", (id-1)))..".html", (string.format("%d", (id+1)))..".html")
      render_with(tostring(id), "templates/news.yats", dir.."/news", out_dir.."/news", lang, tags)
      news_posts[id] = apply_template("templates/news_post.yats", tags, lang)
   end
   local p = 1
   for i = max_id, 1, -10 do
      local archive_page = "news_archive_"..p
      local posts = {}
      for j = i, math.max(i - 9, 1), -1 do
         table.insert(posts, news_posts[j])
      end
      local tags = {
         posts = table.concat(posts, templates.content_hr),
      }
      older_newer(tags, i, 1, math.ceil(max_id / 10), "news_archive_"..(p+1)..".html", "news_archive_"..(p-1)..".html")
      render_with(archive_page, "templates/news_archive.yats", dir.."/news", out_dir.."/news", lang, tags)
      p = p + 1
   end
   return news_posts[max_id]
end

--for lang in lfs.dir("lang") do
for _, lang in ipairs({"en_US"}) do
   if lang ~= "." and lang ~= ".." then
      local out_lang = (lang == "en_US") and "" or lang
      local out_dir = "output/"..out_lang
      os.execute("mkdir -p "..out_dir)
      local dir = "lang/"..lang
      local ok, err = xpcall(function()
         process_pages(dir.."/pages", out_dir, lang)
         local latest_news = process_news(dir.."/news", out_dir, lang)
         render_with("index.yats", "templates/index.yats", "templates/", out_dir, lang, { latest_news = latest_news })
      end, function(err) 
         if verbose then
            print(err); print(debug.traceback())
         end
      end)
      if not ok then
         all_ok = false
         if verbose then
            print(err)
         end
      end
   end
end

os.execute("rm -rf output/images")
os.execute("cp -a images output/")
os.execute("cp -a doc/ output/")

os.exit(all_ok and 0 or 1)

