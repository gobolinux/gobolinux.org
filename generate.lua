#!/usr/bin/env lua

local lfs = require("lfs")

local root_dir = lfs.currentdir().."/output"

local ok = true

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

local function apply_template(filename, tags, lang)
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
      ok = false
      return ""
   end
   local template = fd:read("*a")
   template = template:gsub("<<@([^>]*)>>", function(filename)
      return apply_template(filename, tags, lang)
   end)

   template = template:gsub("<<#([^>]*)>>", function(tag_name)
print(tag_name, tags[tag_name])
      local output = apply_template(tags[tag_name], tags, lang)
      if special_formatters[tag_name] then
         return special_formatters[tag_name](output)
      end
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

local function render_with(page_name, template, src_dir, dst_dir, lang, extra_tags)
   io.stdout:write(page_name.." -> ")
   local tags = {
      page = src_dir.."/"..page_name,
   }
   if extra_tags then
      setmetatable(tags, { __index = extra_tags })
   end
   local rendered = apply_template(template, tags, lang)
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
   local max_id = 0
   local news_posts = {}
   for name in lfs.dir(dir) do
      if name ~= "." and name ~= ".." then
         local id = name:match("(%d+)%.body")
         if id then
            max_id = math.max(max_id, tonumber(id))
         end
      end
   end
   local function older_newer(tags, id, min, max, older_link, newer_link)
      tags.older_news_link = id > min and older_link or ""
      tags.newer_news_link = id < max and newer_link or ""
      tags.older_news = id > min and "strings/older_news" or ""
      tags.newer_news = id < max and "strings/newer_news" or ""
   end
   for name in lfs.dir(dir) do
      if name ~= "." and name ~= ".." then
         local id = name:match("(%d+)%.body")
         if id then
            local nid = tonumber(id)
            local tags = {
               title = "news/"..id..".title",
               body = "news/"..id..".body",
               date = "news/"..id..".date",
               permalink = id..".html",
            }
            older_newer(tags, nid, 1, max_id, (string.format("%d", (id-1)))..".html", (string.format("%d", (id+1)))..".html")
            render_with(id, "templates/news.yats", dir.."/news", out_dir.."/news", lang, tags)
            news_posts[nid] = apply_template("templates/news_post.yats", tags, lang)
         end
      end
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

for lang in lfs.dir("lang") do
   if lang ~= "." and lang ~= ".." then
      local out_lang = (lang == "en_US") and "" or lang
      local out_dir = "output/"..out_lang
      os.execute("mkdir -p "..out_dir)
      local dir = "lang/"..lang
      local ok, err = xpcall(function()
         process_pages(dir.."/pages", out_dir, lang)
         local latest_news = process_news(dir.."/news", out_dir, lang)
         render_with("index.yats", "templates/index.yats", "templates/", out_dir, lang, { latest_news = latest_news })
      end, function(err) print(err); print(debug.traceback()) end )
      if not ok then
         print(err)
      end
   end
end

os.execute("rm -rf output/images")
os.execute("cp -a images output/")
os.execute("cp -a doc/ output/")

os.exit(ok and 0 or 1)

