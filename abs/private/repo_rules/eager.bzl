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

load("//abs/private:util.bzl", "deps_from_file", "have_unblocked_downloads", "storage_account_url")

def _eager_impl(repository_ctx):
    repository_ctx.report_progress("Downloading files from lockfile {}".format(repository_ctx.attr.lockfile))
    deps = deps_from_file(repository_ctx, repository_ctx.attr.lockfile, repository_ctx.attr.lockfile_jsonpath)
    # build_file_content = """load("@rules_abs//abs/private/rules:copy.bzl", "copy")\n"""

    # start downloads
    waiters = []
    for local_path, info in deps.items():
        args = info_to_download_args(repository_ctx.attr.storage_account, repository_ctx.attr.container, local_path, info)
        waiters.append(repository_ctx.download(**args))

    # populate BUILD file
    repository_ctx.file("BUILD.bazel", "exports_files(glob([\"**\"]))".format(args["output"]))

    # wait for downloads to finish
    if have_unblocked_downloads():
        for waiter in waiters:
            waiter.wait()

def info_to_download_args(storage_account, container, local_path, info):
    args = {
        "url": storage_account_url(storage_account, container, info["remote_path"]),
        "output": local_path,
        "executable": True,
        "block": False,
    }
    if not have_unblocked_downloads():
        args.pop("block")
    if "sha256" in info:
        args["sha256"] = info["sha256"]
    if "integrity" in info:
        args["integrity"] = info["integrity"]
    return args

eager = repository_rule(
    implementation = _eager_impl,
    attrs = {
        "storage_account": attr.string(),
        "container": attr.string(),
        "lockfile": attr.label(
            doc = "Map of dependency files to load from Azure Blob Storage",
        ),
        "lockfile_jsonpath": attr.string(),
    },
)
