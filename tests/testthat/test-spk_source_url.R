# The ogr2ogr invocation is verified by building the argument vector and comparing it.
# `.spk_source_url_args()` exists for that: the check matrix has five runners and none is
# guaranteed to carry the GDAL CLI, so a test that shells out is a test that skips.
#
# The failure path is exercised by stubbing system2() rather than fetching a URL that
# 404s. No test in this package touches the network, and a stub hits the same branch
# deterministically — a real 404 would also be untestable offline.

skip_no_ogr <- function() {
  testthat::skip_if(!nzchar(Sys.which("ogr2ogr")), "ogr2ogr CLI not on PATH")
}

# The round-trip tests below prove that arguments survive `sh` parsing. The check matrix
# includes windows-latest, where `shQuote()` defaults to type = "cmd" and `printf` is not
# a command at all -- and system2() on a missing command errors rather than skipping.
skip_no_sh <- function() {
  testthat::skip_on_os("windows")
  testthat::skip_if(!nzchar(Sys.which("printf")), "printf not on PATH")
}

# file(open = "wb", encoding = ) does NOT re-encode on write — it writes the bytes it is
# given. Converting explicitly is the only way to get a genuine UTF-16LE fixture, and a
# fixture that is secretly ASCII cannot reach the failure mode under test.
write_utf16le <- function(lines, path) {
  txt <- paste0(paste(lines, collapse = "\n"), "\n")
  writeBin(iconv(txt, from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)[[1]], path)
  path
}

# spk_source_url() checks Sys.which("ogr2ogr") before its loop. The mock-based tests
# below never reach the CLI, but they do reach that guard -- and four of five check
# runners have no ogr2ogr binary (sf pulls libgdal-dev, which does not ship it). Stubbing
# the guard is what keeps them running there; skipping instead would leave the fix with
# no coverage at all on those runners. Measured: without this, FAIL 6 on macos-latest and
# windows-latest while passing locally, because this machine has GDAL on PATH.
stub_ogr_on_path <- function(f) {
  mockery::stub(f, "Sys.which", function(names) "/usr/bin/ogr2ogr")
  f
}

seed_gpkg <- function() {
  gpkg <- tempfile(fileext = ".gpkg")
  sf::st_write(
    sf::st_sf(id = 1L, geometry = sf::st_sfc(sf::st_point(c(-127, 54)), crs = 4326)),
    gpkg,
    layer = "seed",
    quiet = TRUE
  )
  gpkg
}

# ---- validation -------------------------------------------------------------

testthat::test_that("spk_source_url validates its arguments", {
  dir <- tempdir()
  gpkg <- file.path(dir, "layers.gpkg")

  testthat::expect_error(
    spk_source_url(path_gpkg = 1L, urls = "https://example.com/a.csv"),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_url(path_gpkg = gpkg, urls = 1L),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_url(path_gpkg = gpkg, urls = "https://example.com/a.csv", query = 1L),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_url(path_gpkg = gpkg, urls = "https://example.com/a.csv", a_srs = 1L),
    class = "chk_error"
  )
})

testthat::test_that("spk_source_url requires the parent directory to exist", {
  testthat::expect_error(
    spk_source_url(
      path_gpkg = file.path(tempdir(), "no-such-dir", "layers.gpkg"),
      urls = "https://example.com/a.csv"
    ),
    class = "chk_error"
  )
})

testthat::test_that("spk_source_url rejects a layer vector that does not match urls", {
  gpkg <- file.path(tempdir(), "layers.gpkg")
  testthat::expect_error(
    spk_source_url(
      path_gpkg = gpkg,
      urls = c("https://example.com/a.csv", "https://example.com/b.csv"),
      layer = "only_one"
    ),
    "same length as `urls`"
  )
})

# ---- argument construction --------------------------------------------------

testthat::test_that(".spk_source_url_args builds the base ogr2ogr arguments", {
  args <- .spk_source_url_args(
    path_gpkg = "layers.gpkg",
    source = "/vsicurl/https://example.com/data/thresholds.csv",
    layer = "thresholds"
  )

  testthat::expect_equal(
    args,
    c(
      "-f", "GPKG",
      "layers.gpkg",
      "-update", "-overwrite",
      "-nln", "thresholds",
      "/vsicurl/https://example.com/data/thresholds.csv"
    )
  )
})

testthat::test_that(".spk_source_url_args omits -update when the GeoPackage is absent", {
  args <- .spk_source_url_args("layers.gpkg", "/vsicurl/x", "l", update = FALSE)
  testthat::expect_false("-update" %in% args)
  testthat::expect_false("-overwrite" %in% args)
  # -f GPKG alone creates the file; -update against a missing one is an ogr2ogr error
  testthat::expect_equal(args[1:3], c("-f", "GPKG", "layers.gpkg"))
})

testthat::test_that(".spk_source_url_args expands open_options into repeated -oo", {
  args <- .spk_source_url_args(
    "layers.gpkg", "/vsicurl/x", "sites",
    open_options = c(
      "X_POSSIBLE_NAMES=Longitude",
      "Y_POSSIBLE_NAMES=Latitude",
      "KEEP_GEOM_COLUMNS=NO"
    ),
    a_srs = "EPSG:4326"
  )

  oo <- which(args == "-oo")
  testthat::expect_length(oo, 3L)
  testthat::expect_equal(
    args[oo + 1L],
    c("X_POSSIBLE_NAMES=Longitude", "Y_POSSIBLE_NAMES=Latitude", "KEEP_GEOM_COLUMNS=NO")
  )
  testthat::expect_equal(args[which(args == "-a_srs") + 1L], "EPSG:4326")
  testthat::expect_equal(args[length(args)], "/vsicurl/x")
})

testthat::test_that(".spk_source_url_args keeps a_srs and t_srs distinct", {
  args <- .spk_source_url_args("g.gpkg", "src", "l", a_srs = "EPSG:4326", t_srs = "EPSG:3005")
  testthat::expect_equal(args[which(args == "-a_srs") + 1L], "EPSG:4326")
  testthat::expect_equal(args[which(args == "-t_srs") + 1L], "EPSG:3005")

  neither <- .spk_source_url_args("g.gpkg", "src", "l")
  testthat::expect_false(any(c("-a_srs", "-t_srs", "-oo", "-where") %in% neither))
})

testthat::test_that(".spk_source_url_args passes query to -where unquoted", {
  q <- "watershed_group_code in ('ADMS')"
  args <- .spk_source_url_args("g.gpkg", "src", "l", query = q)
  # Unquoted in the builder by design. system2() DOES run its args through `sh` -- the
  # comment here previously claimed the opposite, which is the reasoning that removed
  # shQuote() in 0.3.0 and broke -where. Quoting happens in .spk_ogr2ogr() instead, so
  # this vector stays comparable by equality.
  testthat::expect_equal(args[which(args == "-where") + 1L], q)
})

# ---- failure is loud --------------------------------------------------------

testthat::test_that(".spk_ogr2ogr aborts naming the URL and the stderr tail", {
  testthat::skip_if_not_installed("mockery")

  f <- .spk_ogr2ogr
  mockery::stub(f, "system2", function(command, args, stdout, stderr, ...) {
    writeLines(c("ERROR 4: /vsicurl/... not recognized", "ERROR 1: unable to open"), stderr)
    1L
  })

  testthat::expect_error(
    f(c("-f", "GPKG"), "https://example.com/missing.csv"),
    "missing\\.csv"
  )
  testthat::expect_error(
    f(c("-f", "GPKG"), "https://example.com/missing.csv"),
    "unable to open"
  )
})

testthat::test_that(".spk_ogr2ogr shell-quotes every argument", {
  # system2() pastes args into a command string run through sh, quoting only the command.
  # Measured: system2("echo", args = "a&b") prints "a" and reports `sh: b: command not
  # found`. A query-string URL was therefore split at each `&`, and the trailing
  # `count=1` was read by sh as a successful variable assignment -- so ogr2ogr reported
  # status 0 having written no file. Silent failure, on the exact URL shape `vsi` exists
  # to support.
  testthat::skip_if_not_installed("mockery")

  seen <- NULL
  f <- .spk_ogr2ogr
  mockery::stub(f, "system2", function(command, args, ...) {
    seen <<- args
    0L
  })

  url <- "https://example.com/ows?service=WFS&count=1"
  f(c("-f", "GPKG", "out.gpkg", "-where", "code in ('ADMS')", paste0("/vsicurl_streaming/", url)), url)

  # The property is not which quoting style shQuote picked -- it uses single quotes
  # normally and switches the whole vector to double quotes, escaping `$` and backticks,
  # as soon as any element contains a single quote. The property is that every argument
  # survives shell parsing byte-identical. Proved by round-tripping through `printf`,
  # which needs no GDAL.
  raw <- c("-f", "GPKG", "out.gpkg", "-where", "code in ('ADMS')",
           paste0("/vsicurl_streaming/", url))
  # Platform-independent, so the windows runner covers the fix too: there shQuote()
  # defaults to cmd quoting, which an sh round-trip could not validate.
  testthat::expect_equal(seen, shQuote(raw))

  # And the property itself -- the arguments survive shell parsing byte-identical --
  # proved by round-tripping through printf where there is an sh to do it.
  skip_no_sh()
  round_tripped <- system2("printf", c(shQuote("%s\n", type = "sh"), seen), stdout = TRUE)
  testthat::expect_equal(round_tripped, raw)
})

testthat::test_that("premise: shQuote survives shell metacharacters", {
  # A PREMISE about base R, not coverage of the fix -- it calls no package function and
  # stays green if shQuote() is removed from .spk_ogr2ogr(). The guard on the fix is
  # ".spk_ogr2ogr shell-quotes every argument" above. Kept because it is the assumption
  # the fix rests on: a URL may carry $ and backticks, a -where clause carries single
  # quotes, and a string holding both is what would break a naive double-quoting.
  skip_no_sh()
  nasty <- c("u?a=1&b=$HOME&c=`id`", "name = 'a$b'", "plain")
  testthat::expect_equal(
    system2("printf", c(shQuote("%s\n", type = "sh"), shQuote(nasty, type = "sh")),
            stdout = TRUE),
    nasty
  )
})

testthat::test_that("an ampersand in a source URL does not silently succeed", {
  # the end-to-end version of the above, against a local file whose name carries a shell
  # metacharacter -- no network, but the same parsing path
  skip_no_ogr()
  testthat::skip_if_not_installed("sf")

  dir <- file.path(tempdir(), "spk-shell-test")
  dir.create(dir, showWarnings = FALSE)
  src <- file.path(dir, "a&b c.csv")
  writeLines(c("code,Longitude,Latitude", "ADMS,-127.1,54.2", "BULK,-126.9,54.4"), src)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)

  args <- .spk_source_url_args(
    path_gpkg = gpkg, source = src, layer = "t",
    query = "code in ('ADMS')",
    open_options = c("X_POSSIBLE_NAMES=Longitude", "Y_POSSIBLE_NAMES=Latitude"),
    a_srs = "EPSG:4326", update = FALSE
  )
  .spk_ogr2ogr(args, src)

  testthat::expect_true(file.exists(gpkg))
  got <- sf::st_read(gpkg, layer = "t", quiet = TRUE)
  # -where actually filtered: 1 of 2 rows. Unquoted this died with a shell syntax error.
  testthat::expect_equal(nrow(got), 1L)
  testthat::expect_equal(got$code, "ADMS")
})

testthat::test_that(".spk_ogr2ogr is silent on success", {
  testthat::skip_if_not_installed("mockery")

  f <- .spk_ogr2ogr
  mockery::stub(f, "system2", function(...) 0L)
  testthat::expect_silent(out <- f(c("-f", "GPKG"), "https://example.com/ok.csv"))
  testthat::expect_null(out)
})

# ---- encoding ---------------------------------------------------------------

testthat::test_that(".spk_reencode converts a UTF-16LE source to UTF-8", {
  src <- tempfile(fileext = ".csv")
  on.exit(unlink(src), add = TRUE)

  # bilingual, slash-separated headers are the shape this exists for
  write_utf16le(c("Site/Site,Year/Annee,Longitude,Latitude", "S1,2024,-127.1,54.2"), src)

  # read as UTF-8 the header is unusable
  raw_head <- readLines(src, n = 1L, warn = FALSE)
  testthat::expect_false(identical(raw_head, "Site/Site,Year/Annee,Longitude,Latitude"))

  out <- .spk_reencode(src, "UTF-16LE", "csv")
  on.exit(unlink(out), add = TRUE)

  lines <- readLines(out, warn = FALSE)
  testthat::expect_equal(lines[[1]], "Site/Site,Year/Annee,Longitude,Latitude")
  testthat::expect_equal(lines[[2]], "S1,2024,-127.1,54.2")
})

testthat::test_that(".spk_source_resolve streams through /vsicurl when encoding is NULL", {
  testthat::expect_equal(
    .spk_source_resolve("https://example.com/a.csv"),
    "/vsicurl/https://example.com/a.csv"
  )
})

# ---- virtual filesystem selection -------------------------------------------

# Measured 2026-09-04, GDAL 3.13.0: a BCGW WFS GetFeature endpoint 404s on HEAD and
# returns a full-body 200 to a Range request rather than a 206, so /vsicurl/'s probe
# fails before any driver is tried. /vsicurl_streaming/ issues one sequential GET.
# The live check is in planning findings; it cannot live here because no test in this
# package touches the network.

testthat::test_that(".spk_source_resolve honours vsi", {
  testthat::expect_equal(
    .spk_source_resolve("https://example.com/a.csv", vsi = "curl"),
    "/vsicurl/https://example.com/a.csv"
  )
  testthat::expect_equal(
    .spk_source_resolve("https://example.com/a.csv", vsi = "curl_streaming"),
    "/vsicurl_streaming/https://example.com/a.csv"
  )
})

testthat::test_that(".spk_source_resolve keeps a query string intact", {
  url <- "https://example.com/ows?service=WFS&typeName=pub%3AX&outputFormat=application%2Fjson"
  testthat::expect_equal(
    .spk_source_resolve(url, vsi = "curl_streaming"),
    paste0("/vsicurl_streaming/", url)
  )
})

testthat::test_that("spk_source_url rejects an unknown vsi, naming the valid values", {
  gpkg <- file.path(tempdir(), "layers.gpkg")
  msg <- tryCatch(
    spk_source_url(
      path_gpkg = gpkg,
      urls = "https://example.com/a.csv",
      vsi = "vsis3"
    ),
    error = conditionMessage
  )
  # the valid set, not merely the argument name -- a message that says only "invalid
  # `vsi`" leaves the caller guessing at the spelling
  testthat::expect_match(msg, "curl_streaming")
  testthat::expect_match(msg, "vsi")
})

testthat::test_that("vsi refuses a partial match rather than resolving it", {
  # match.arg() would accept "curl_stream" as a unique prefix of "curl_streaming" and
  # proceed. That was measured: the call went on to shell out to ogr2ogr against a live
  # URL, which no test in this package may do. Exact matching is deliberate.
  gpkg <- file.path(tempdir(), "layers.gpkg")
  msg <- tryCatch(
    spk_source_url(path_gpkg = gpkg, urls = "https://example.com/a.csv", vsi = "curl_stream"),
    error = conditionMessage
  )
  testthat::expect_match(msg, "curl_stream")
  testthat::expect_match(msg, "vsi")
})

testthat::test_that("spk_source_url refuses encoding combined with a non-default vsi", {
  gpkg <- file.path(tempdir(), "layers.gpkg")
  msg <- tryCatch(
    spk_source_url(
      path_gpkg = gpkg,
      urls = "https://example.com/a.csv",
      layer = "a",
      encoding = "UTF-16LE",
      vsi = "curl_streaming"
    ),
    error = conditionMessage
  )
  testthat::expect_match(msg, "encoding")
  testthat::expect_match(msg, "vsi")
  # the two are competing statements about transport; the message must say so rather
  # than only naming the arguments
  testthat::expect_match(msg, "downloaded|download")
})

testthat::test_that("spk_source_url allows encoding with the default vsi", {
  # the mutual exclusion must not fire for callers who never mention vsi -- this is the
  # whole existing encoding path and it has to keep working. Both the fetch and the CLI
  # are stubbed: no test here touches the network.
  testthat::skip_if_not_installed("mockery")

  gpkg <- file.path(tempdir(), "layers.gpkg")
  local <- tempfile(fileext = ".csv")
  writeLines("Site,Longitude,Latitude", local)
  on.exit(unlink(local), add = TRUE)

  seen <- NULL
  f <- stub_ogr_on_path(spk_source_url)
  mockery::stub(f, ".spk_source_resolve", function(...) local)
  mockery::stub(f, ".spk_ogr2ogr", function(args, url) {
    seen <<- args
    invisible(NULL)
  })

  testthat::expect_no_error(
    f(
      path_gpkg = gpkg,
      urls = "https://example.com/a.csv",
      encoding = "UTF-16LE"
    )
  )
  testthat::expect_equal(seen[[length(seen)]], local)
})

testthat::test_that("every temp file is cleaned up, not just the last", {
  # on.exit() registered inside the loop stores an unevaluated expression, so all three
  # registrations resolved to the LAST value of `source`: the third temp file was
  # unlinked three times and the first two leaked for the life of the session. Measured
  # at 2 of 3 surviving before the fix.
  testthat::skip_if_not_installed("mockery")

  gpkg <- file.path(tempdir(), "layers.gpkg")
  made <- character(0)

  f <- stub_ogr_on_path(spk_source_url)
  mockery::stub(f, ".spk_source_resolve", function(...) {
    p <- tempfile(fileext = ".csv")
    writeLines("Site,Longitude,Latitude", p)
    made <<- c(made, p)
    p
  })
  mockery::stub(f, ".spk_ogr2ogr", function(...) invisible(NULL))

  f(
    path_gpkg = gpkg,
    urls = c(
      "https://example.com/a.csv",
      "https://example.com/b.csv",
      "https://example.com/c.csv"
    ),
    layer = c("a", "b", "c"),
    encoding = "UTF-16LE"
  )

  testthat::expect_length(made, 3L)
  testthat::expect_equal(sum(file.exists(made)), 0L)
})

testthat::test_that("an encoded source still registers its temp file for cleanup", {
  # the mirror of the streaming case below: the encoding branch is the one that really
  # does write a temp file, and replacing the cleanup check must not drop it
  testthat::skip_if_not_installed("mockery")

  gpkg <- file.path(tempdir(), "layers.gpkg")
  local <- tempfile(fileext = ".csv")
  writeLines("Site,Longitude,Latitude", local)
  on.exit(unlink(local), add = TRUE)

  unlinked <- character(0)
  f <- stub_ogr_on_path(spk_source_url)
  mockery::stub(f, ".spk_source_resolve", function(...) local)
  mockery::stub(f, ".spk_ogr2ogr", function(...) invisible(NULL))
  mockery::stub(f, "unlink", function(x, ...) {
    unlinked <<- c(unlinked, x)
    0L
  })

  f(
    path_gpkg = gpkg,
    urls = "https://example.com/a.csv",
    encoding = "UTF-16LE"
  )

  testthat::expect_true(local %in% unlinked)
})

# ---- layer names derived from a query-string URL ----------------------------

testthat::test_that("spk_source_url requires layer when a URL carries a query string", {
  gpkg <- file.path(tempdir(), "layers.gpkg")
  url <- "https://example.com/ows?service=WFS&request=GetFeature&typeName=pub%3AX"

  msg <- tryCatch(
    spk_source_url(path_gpkg = gpkg, urls = url, vsi = "curl_streaming"),
    error = conditionMessage
  )
  testthat::expect_match(msg, "layer")
  testthat::expect_match(msg, "query string")

  # measured: the derived name would otherwise be the entire query string
  testthat::expect_true(grepl("?", tools::file_path_sans_ext(basename(url)), fixed = TRUE))
})

testthat::test_that("the layer guard fires before any ogr2ogr runs", {
  # a good URL first, a query-string URL second: the abort must happen in pre-flight,
  # not after the first layer has already been written to the GeoPackage
  testthat::skip_if_not_installed("mockery")

  gpkg <- file.path(tempdir(), "layers.gpkg")
  called <- FALSE
  f <- stub_ogr_on_path(spk_source_url)
  mockery::stub(f, ".spk_ogr2ogr", function(...) {
    called <<- TRUE
    invisible(NULL)
  })

  testthat::expect_error(
    f(
      path_gpkg = gpkg,
      urls = c("https://example.com/a.csv", "https://example.com/ows?service=WFS"),
      vsi = "curl_streaming"
    ),
    "query string"
  )
  testthat::expect_false(called)
})

testthat::test_that("a supplied layer makes a query-string URL legal", {
  testthat::skip_if_not_installed("mockery")

  gpkg <- file.path(tempdir(), "layers.gpkg")
  seen <- NULL
  f <- stub_ogr_on_path(spk_source_url)
  mockery::stub(f, ".spk_ogr2ogr", function(args, url) {
    seen <<- args
    invisible(NULL)
  })

  url <- "https://example.com/ows?service=WFS&typeName=pub%3AX"
  f(path_gpkg = gpkg, urls = url, layer = "streams", vsi = "curl_streaming")

  testthat::expect_equal(seen[[length(seen)]], paste0("/vsicurl_streaming/", url))
  testthat::expect_equal(seen[which(seen == "-nln") + 1L], "streams")
})

# ---- temp-file cleanup ------------------------------------------------------

testthat::test_that("a streaming source registers no temp-file cleanup", {
  # the cleanup decision must not be made by reconstructing the /vsicurl/ string --
  # with vsi = "curl_streaming" the resolved source is not that string, and the old
  # check would have registered unlink() against a virtual path
  testthat::skip_if_not_installed("mockery")

  gpkg <- file.path(tempdir(), "layers.gpkg")
  unlinked <- character(0)
  f <- stub_ogr_on_path(spk_source_url)
  mockery::stub(f, ".spk_ogr2ogr", function(...) invisible(NULL))
  mockery::stub(f, "unlink", function(x, ...) {
    unlinked <<- c(unlinked, x)
    0L
  })

  f(
    path_gpkg = gpkg,
    urls = "https://example.com/ows?service=WFS",
    layer = "streams",
    vsi = "curl_streaming"
  )

  testthat::expect_false(any(grepl("^/vsi", unlinked)))
})

# ---- end to end, offline, only where GDAL exists ----------------------------

testthat::test_that("a UTF-16 coordinate CSV becomes a point layer", {
  skip_no_ogr()
  testthat::skip_if_not_installed("sf")

  src <- tempfile(fileext = ".csv")
  write_utf16le(c("Site,Longitude,Latitude", "S1,-127.1,54.2", "S2,-126.9,54.4"), src)
  on.exit(unlink(src), add = TRUE)

  utf8 <- .spk_reencode(src, "UTF-16LE", "csv")
  on.exit(unlink(utf8), add = TRUE)

  gpkg <- seed_gpkg()
  on.exit(unlink(gpkg), add = TRUE)

  args <- .spk_source_url_args(
    path_gpkg = gpkg,
    source = utf8,
    layer = "sites",
    open_options = c(
      "X_POSSIBLE_NAMES=Longitude",
      "Y_POSSIBLE_NAMES=Latitude",
      "KEEP_GEOM_COLUMNS=NO"
    ),
    a_srs = "EPSG:4326",
    update = TRUE
  )
  .spk_ogr2ogr(args, src)

  testthat::expect_true("sites" %in% sf::st_layers(gpkg)$name)
  got <- sf::st_read(gpkg, layer = "sites", quiet = TRUE)
  testthat::expect_equal(nrow(got), 2L)
  testthat::expect_false(all(sf::st_is_empty(got)))
  testthat::expect_equal(sf::st_crs(got)$epsg, 4326L)
})

testthat::test_that("spk_source_url creates the GeoPackage when it does not exist", {
  skip_no_ogr()
  testthat::skip_if_not_installed("sf")

  src <- tempfile(fileext = ".csv")
  writeLines(c("Site,Longitude,Latitude", "S1,-127.1,54.2"), src)
  on.exit(unlink(src), add = TRUE)

  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)
  testthat::expect_false(file.exists(gpkg))

  args <- .spk_source_url_args(
    path_gpkg = gpkg, source = src, layer = "sites",
    open_options = c("X_POSSIBLE_NAMES=Longitude", "Y_POSSIBLE_NAMES=Latitude"),
    a_srs = "EPSG:4326", update = FALSE
  )
  .spk_ogr2ogr(args, src)

  testthat::expect_true(file.exists(gpkg))
  testthat::expect_true("sites" %in% sf::st_layers(gpkg)$name)
})

testthat::test_that("a real ogr2ogr failure aborts with its stderr", {
  skip_no_ogr()

  gpkg <- file.path(tempdir(), "unused.gpkg")
  args <- .spk_source_url_args(
    path_gpkg = gpkg,
    source = file.path(tempdir(), "definitely-not-here.csv"),
    layer = "x",
    update = FALSE
  )
  testthat::expect_error(.spk_ogr2ogr(args, "definitely-not-here.csv"), "ogr2ogr failed")
})
