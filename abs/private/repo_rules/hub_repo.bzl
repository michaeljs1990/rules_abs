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

load("//abs/private:util.bzl", "deps_from_file", "object_repo_name")

def _alias_hub_repo_impl(repository_ctx):
    repository_ctx.report_progress("Rebuilding Azure Strorage Account alias tree")
    deps = deps_from_file(repository_ctx, repository_ctx.attr.lockfile, repository_ctx.attr.lockfile_jsonpath)
    build_file_content = ""
    for local_path, info in deps.items():
        build_file_content += dep_to_alias_build_file(
            repository_ctx.attr.storage_account,
            repository_ctx.attr.container,
            local_path,
            info["remote_path"],
        )
    repository_ctx.file("BUILD.bazel", build_file_content)

def dep_to_alias_build_file(storage_account, container, local_path, remote_path):
    template = """
alias(
    name = "{}",
    actual = "{}",
    visibility = ["//visibility:public"],
)
    """
    return template.format(container + "/" +local_path, "@{}//file".format(object_repo_name(storage_account, container, remote_path)))

alias_hub_repo = repository_rule(
    implementation = _alias_hub_repo_impl,
    attrs = {
        "storage_account": attr.string(),
        "container": attr.string(),
        "lockfile": attr.label(
            doc = "Map of dependency files to load from the Azure Strorage Account",
        ),
        "lockfile_jsonpath": attr.string(),
    },
)

def _symlink_hub_repo_impl(repository_ctx):
    repository_ctx.report_progress("Rebuilding Azure Blob Storage symlink tree")
    deps = deps_from_file(repository_ctx, repository_ctx.attr.lockfile, repository_ctx.attr.lockfile_jsonpath)
    build_file_content = """load("@rules_abs//abs/private/rules:symlink.bzl", "symlink")\n"""
    for local_path, info in deps.items():
        build_file_content += dep_to_symlink_build_file(
            repository_ctx.attr.storage_account,
            repository_ctx.attr.container,
            local_path,
            info["remote_path"],
        )
    repository_ctx.file("BUILD.bazel", build_file_content)

def dep_to_symlink_build_file(storage_account, container, local_path, remote_path):
    template = """
symlink(
    name = "{}",
    target = "{}",
    visibility = ["//visibility:public"],
)
    """
    return template.format(container + "/" +local_path, "@{}//file".format(object_repo_name(storage_account, container, remote_path)))

symlink_hub_repo = repository_rule(
    implementation = _symlink_hub_repo_impl,
    attrs = {
        "storage_account": attr.string(),
        "container": attr.string(),
        "lockfile": attr.label(
            doc = "Map of dependency files to load from the Azure Strorage Account",
        ),
        "lockfile_jsonpath": attr.string(),
    },
)

def _copy_hub_repo_impl(repository_ctx):
    repository_ctx.report_progress("Rebuilding Azure Blob Storage copy tree")
    deps = deps_from_file(repository_ctx, repository_ctx.attr.lockfile, repository_ctx.attr.lockfile_jsonpath)
    build_file_content = """load("@rules_abs//abs/private/rules:copy.bzl", "copy")\n"""
    for local_path, info in deps.items():
        build_file_content += dep_to_copy_build_file(
            repository_ctx.attr.storage_account,
            repository_ctx.attr.container,
            local_path,
            info["remote_path"],
        )
    repository_ctx.file("BUILD.bazel", build_file_content)

def dep_to_copy_build_file(storage_account, container, local_path, remote_path):
    template = """
copy(
    name = "{}",
    src = "{}",
    visibility = ["//visibility:public"],
)
    """
    return template.format(container + "/" +local_path, "@{}//file".format(object_repo_name(storage_account, container, remote_path)))

copy_hub_repo = repository_rule(
    implementation = _copy_hub_repo_impl,
    attrs = {
        "storage_account": attr.string(),
        "container": attr.string(),
        "lockfile": attr.label(
            doc = "Map of dependency files to load from the Azure Strorage Account",
        ),
        "lockfile_jsonpath": attr.string(),
    },
)
