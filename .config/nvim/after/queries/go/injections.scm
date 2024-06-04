; extends
((raw_string_literal) @injection.content
  (#match? @injection.content ".*(^|\n)(from.*import|def )")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "python"))
