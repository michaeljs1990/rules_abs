"""
Copyright 2024 IMAX Corporation
Copyright 2024 Modus Create LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

# load("//abs/private:url_encoding.bzl", "url_encode")
load("//abs/private:util.bzl", "download_abs_args", "have_unblocked_downloads", "parse_abs_url")

def _abs_file_impl(repository_ctx):
    url = repository_ctx.attr.url
    target = parse_abs_url(url)
    repository_ctx.report_progress("Fetching {}".format(url))

    # start download
    args = download_abs_args(repository_ctx.attr, target["remote_path"])
    waiter = repository_ctx.download(**args)

    # populate BUILD files
    repository_ctx.file("BUILD.bazel", "exports_files(glob([\"**\"]))".format(args["output"]))
    rulename = "augmented_executable" if repository_ctx.attr.executable else "augmented_blob"
    build_file_content = """load("@rules_abs//abs/private/rules:augmented_blob.bzl", "{}")\n""".format(rulename)
    build_file_content += template_augmented(args["output"], target["remote_path"], repository_ctx.attr.executable)
    repository_ctx.file("file/BUILD.bazel", build_file_content)

    # wait for download to finish
    if have_unblocked_downloads():
        waiter.wait()

_abs_file_doc = """Downloads a file from an Azure Blob Storage bucket and makes it available to be used as a file group.

Examples:
  Suppose you need to have a large file that is read during a test and is stored in a private bucket.
  This file is available from https://myorg.blob.core.windows.net/junk/azure-cli-2.66.1-x64.zip.
  Then you can add to your MODULE.bazel file:

  ```starlark
  abs_file = use_repo_rule("@rules_abs//abs:repo_rules.bzl", "abs_file")

  abs_file(
      name = "azure_cli",
      url = "https://myorg.blob.core.windows.net/junk/azure-cli-2.66.1-x64.zip",
      sha256 = "9567c5e8d7fe0d4dc9351b85fdab254ccc5f4218c4def688f44d7e76c20a3d29",
  )
  ```

  Targets would specify `@azure_cli//file` as a dependency to depend on this file."""

_abs_file_attrs = {
    "canonical_id": attr.string(
        doc = """A canonical ID of the file downloaded.

If specified and non-empty, Bazel will not take the file from cache, unless it
was added to the cache by a request with the same canonical ID.

If unspecified or empty, Bazel by default uses the URLs of the file as the
canonical ID. This helps catch the common mistake of updating the URLs without
also updating the hash, resulting in builds that succeed locally but fail on
machines without the file in the cache.
""",
    ),
    "downloaded_file_path": attr.string(
        doc = "Optional output path for the downloaded file. The remote path from the URL is used as a fallback.",
    ),
    "executable": attr.bool(
        doc = "If the downloaded file should be made executable.",
    ),
    "integrity": attr.string(
        doc = """Expected checksum in Subresource Integrity format of the file downloaded.

This must match the checksum of the file downloaded. It is a security risk
to omit the checksum as remote files can change. At best omitting this
field will make your build non-hermetic. It is optional to make development
easier but either this attribute or `sha256` should be set before shipping.""",
    ),
    "sha256": attr.string(
        doc = """The expected SHA-256 of the file downloaded.

This must match the SHA-256 of the file downloaded. _It is a security risk
to omit the SHA-256 as remote files can change._ At best omitting this
field will make your build non-hermetic. It is optional to make development
easier but should be set before shipping.""",
    ),
    "url": attr.string(
        mandatory = True,
        doc = "A URL to a file that will be made available to Bazel.\nThis must be a 'https://' URL.",
    ),
}

abs_file = repository_rule(
    implementation = _abs_file_impl,
    attrs = _abs_file_attrs,
    doc = _abs_file_doc,
)

def template_augmented(local_path, remote_path, executable):
    rulename = "augmented_executable" if executable else "augmented_blob"
    template = """
{}(
    name = "file",
    local_path = "//:{}",
    remote_path = "{}",
    visibility = ["//visibility:public"],
)
"""
    return template.format(rulename, local_path, remote_path)
