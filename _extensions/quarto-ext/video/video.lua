-- === Utils ===
-- from http://lua-users.org/wiki/StringInterpolation
local interpolate = function(str, vars)
  -- Allow replace_vars{str, vars} syntax as well as replace_vars(str, {vars})
  if not vars then
    vars = str
    str = vars[1]
  end
  return (string.gsub(str, "({([^}]+)})",
          function(whole, i)
            return vars[i] or whole
          end))
end

local function isEmpty(s)
  return s == nil or s == ''
end

local isResponsive = function(width, height)
  return isEmpty(height) and isEmpty(width)
end

VIDEO_SHORTCODE_NUM_VIDEOJS = 0

local VIDEO_TYPES = {
  YOUTUBE = "YOUTUBE",
  BRIGHTCOVE = "BRIGHTCOVE",
  VIMEO = "VIMEO",
  VIDEOJS = "VIDEOJS"
}

local ASPECT_RATIOS = {
  ["1x1"] = "ratio-1x1",
  ["4x3"] = "ratio-4x3",
  ["16x9"] = "ratio-16x9",
  ["21x9"] = "ratio-21x9"
}

local DEFAULT_ASPECT_RATIO = ASPECT_RATIOS["16x9"]

local wrapForResponsive = function(toWrap, aspectRatio)
  local ratioClass = aspectRatio and ASPECT_RATIOS[aspectRatio] or DEFAULT_ASPECT_RATIO

  wrapper = [[<div class="ratio {ratioClass}">{toWrap}</div>]]

  return interpolate {
    wrapper,
    toWrap = toWrap,
    ratioClass = ratioClass }
end

local EXTRACT_NOT_FOUND = { type = 'NOT_FOUND', src = '' }
local extractTypeAndSrc = function(src)
  if (src == nil) then
    return EXTRACT_NOT_FOUND
  end

  local checkEndMatch = function(value, matcherFront)
    return string.match(value, matcherFront .. '(.-)$')
  end

  local isBrightcove = function()
    return string.find(src, 'https://players.brightcove.net')
  end

  if (isBrightcove()) then
    return { type = VIDEO_TYPES.BRIGHTCOVE, src = src }
  end

  local VIMEO_STANDARD = 'https://vimeo.com/'
  local match = checkEndMatch(src, VIMEO_STANDARD)
  if (match) then
    return { type = "VIMEO", src = 'https://player.vimeo.com/video/' .. match }
  end

  local YOUTUBE_EMBED = 'https://www.youtube.com/embed/'
  local buildYouTubeResult = function(endSrc)
    return { type = VIDEO_TYPES.YOUTUBE, src = YOUTUBE_EMBED .. endSrc }
  end

  match = checkEndMatch(src, YOUTUBE_EMBED)
  if (match) then
    return buildYouTubeResult(match)
  end

  local YOUTUBE_SHARE = 'https://youtu.be/'
  match = checkEndMatch(src, YOUTUBE_SHARE)
  if (match) then
    return buildYouTubeResult(match)
  end

  match = string.match(src, '%?v=(.-)&')
  if (match) then
    return buildYouTubeResult(match)
  end

  match = string.match(src, '%?v=(.-)$')
  if (match) then
    return buildYouTubeResult(match)
  end

  if (not isEmpty(src)) then
    return { type = VIDEO_TYPES.VIDEOJS, src = src }
  end

  return EXTRACT_NOT_FOUND
end

local replaceCommonAttributes = function(snippet, params)
  result = interpolate {
    snippet,
    src = params.src,
    height = params.height and ' height="' .. params.height .. '"' or '',
    width = params.width and ' width="' .. params.width .. '"' or '',
    title = params.title or '',
  }
  return result
end

-- === YouTube ===
local buildYouTube = function(params)
  local SNIPPET = [[<iframe src="{src}{start}"{width}{height} title="{title}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>]]
  local snippet = params.snippet or SNIPPET
  snippet = replaceCommonAttributes(snippet, params)
  result = interpolate {
    snippet,
    start = params.start and '?start=' .. params.start or ''
  }
  return result
end

-- === Brightcove ===
local buildBrightcove = function(params)
  local SNIPPET = [[<iframe src="{src}"{width}{height} allowfullscreen="" allow="encrypted-media"></iframe>]]
  local snippet = params.snippet or SNIPPET
  result = replaceCommonAttributes(snippet, params)
  return result
end

-- === Vimeo ===
local buildVimeo = function(params)
  local SNIPPET = [[<iframe src="{src}"{width}{height} frameborder="0" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe>]]
  local snippet = params.snippet or SNIPPET
  result = replaceCommonAttributes(snippet, params)
  return result
end

-- === VideoJS ===
local buildVideoJS = function(params)
  local SNIPPET = [[
 <video id="{id}"{width}{height} class="video-js vjs-default-skin {fluid}" controls preload="auto"
  data-setup='{}'>
    <source src="{src}">
  </video>
 ]]
  local snippet = params.snippet or SNIPPET
  snippet = replaceCommonAttributes(snippet, params)
  snippet = interpolate {
    snippet,
    id = params.id or '',
    fluid = isResponsive(params.width, params.height) and 'vjs-fluid' or ''
  }
  return snippet
end

local helpers = {
  ["buildYouTube"] = buildYouTube,
  ["buildBrightcove"] = buildBrightcove,
  ["buildVimeo"] = buildVimeo,
  ["buildVideoJS"] = buildVideoJS,
  ["extractTypeAndSrc"] = extractTypeAndSrc,
  ["wrapForResponsive"] = wrapForResponsive,
  ["EXTRACT_NOT_FOUND"] = EXTRACT_NOT_FOUND,
  ["VIDEO_TYPES"] = VIDEO_TYPES
}

-- === Pandoc Shortcode ===
function htmlVideo(src, height, width, title, start, aspectRatio)
  local typeAndSrc = extractTypeAndSrc(src)
  local videoSnippet

  local isVideoJS = function()
    return typeAndSrc.type == VIDEO_TYPES.VIDEOJS
  end

  if (typeAndSrc.type == VIDEO_TYPES.YOUTUBE) then
    videoSnippet = buildYouTube { src = typeAndSrc.src, height = height, width = width, title = title, start = start }
  end

  if (typeAndSrc.type == VIDEO_TYPES.BRIGHTCOVE) then
    videoSnippet = buildBrightcove { src = typeAndSrc.src, title = title, height = height, width = width }
  end

  if (typeAndSrc.type == VIDEO_TYPES.VIMEO) then
    videoSnippet = buildVimeo { src = typeAndSrc.src, title = title, height = height, width = width }
  end

  if (isEmpty(videoSnippet)) then
    quarto.doc.addHtmlDependency({
      name = 'videojs',
      scripts = { 'resources/videojs/video.min.js' },
      stylesheets = { 'resources/videojs/video-js.css' }
    })
    VIDEO_SHORTCODE_NUM_VIDEOJS = VIDEO_SHORTCODE_NUM_VIDEOJS + 1
    local id = "video_shortcode_videojs_video" .. VIDEO_SHORTCODE_NUM_VIDEOJS
    local scriptTag = "<script>videojs(" .. id .. ");</script>"
    quarto.doc.includeText("after-body", scriptTag)

    videoSnippet = buildVideoJS { src = typeAndSrc.src, id = id, title = title, height = height, width = width }
  end

  if isResponsive(width, height)
          and not quarto.doc.isFormat('revealjs')
          and not isVideoJS() then
    if (not quarto.doc.hasBootstrap()) then
      quarto.doc.addHtmlDependency({
        name = 'bootstrap-responsive',
        stylesheets = { 'resources/bootstrap/bootstrap-responsive-ratio.css' }
      })
    end

    videoSnippet = wrapForResponsive(
            videoSnippet,
            aspectRatio
    )
  end

  -- inject the rendering code
  return pandoc.RawBlock('html', videoSnippet)
end
-- return a table containing shortcode definitions
-- defining shortcodes this way allows us to create helper
-- functions that are not themselves considered shortcodes
return {
  ["video"] = function(args, kwargs)
    checkArg = function(toCheck, key)
      value = pandoc.utils.stringify(toCheck[key])
      if not isEmpty(value) then
        return value
      else
        return nil
      end
    end

    local srcValue = checkArg(kwargs, 'src')
    local titleValue = checkArg(kwargs, 'title')
    local startValue = checkArg(kwargs, 'start')
    local heightValue = checkArg(kwargs, 'height')
    local widthValue = checkArg(kwargs, 'width')
    local aspectRatio = checkArg(kwargs, 'aspectRatio')

    if isEmpty(aspectRatio) then
      aspectRatio = checkArg(kwargs, 'aspect-ratio')
    end

    if #args == 1 and isEmpty(srcValue) then
      srcValue = pandoc.utils.stringify(args[1])
    end

    if quarto.doc.isFormat("html:js") then
      return htmlVideo(srcValue, heightValue, widthValue, titleValue, startValue, aspectRatio)
    else
      -- Fall-back to a link of the source
      return pandoc.Link(srcValue, srcValue)
    end

  end,
  ["video-helpers"] = helpers
}