# rules_abs

Bazel rules for downloading files from [Azure Blob Storage (ABS)][abs].

## Features

- Can be used as a drop-in replacement for `http_file` (`abs_file`) and `http_archive` (`abs_archive`)
- Can fetch large amounts of objects lazily from a bucket using the `abs_container` module extension
- Supports fetching from private buckets using a credential helper
- Uses Bazel's downloader and the repository cache
- No dependencies like the Azure cli (`az`) need to be installed for access of public repos

## Installation

You can find the latest version of [`rules_abs` on the Bazel Central Registry][bcr]. Installation works by adding a `bazel_dep` line to `MODULE.bazel`.

```starlark
bazel_dep(name = "rules_abs", version = "0.1.0")
```


If you need to configure a credential helper to download from a private repo an example exists in [examples/full][example_cred_helper] that will work if `az` is installed.
I have planned work to add support for this to the [credential-helper](https://github.com/tweag/credential-helper/issues/50) so that `az` is no longer required.

## Usage

`rules_abs` offers two repository rules [`abs_file`](#abs_file) and [`abs_archive`](#abs_archive) for fetching individual objects.
If you need to download multiple objects from a container, use the [`abs_container`](#abs_container) module extension instead.

To see how it all comes together, take a look at the [full example][example].

<a id="abs_archive"></a>

## abs_archive

<pre>
load("@rules_abs//abs:repo_rules.bzl", "abs_archive")

abs_archive(<a href="#abs_archive-name">name</a>, <a href="#abs_archive-build_file">build_file</a>, <a href="#abs_archive-build_file_content">build_file_content</a>, <a href="#abs_archive-canonical_id">canonical_id</a>, <a href="#abs_archive-integrity">integrity</a>, <a href="#abs_archive-patch_strip">patch_strip</a>, <a href="#abs_archive-patches">patches</a>,
            <a href="#abs_archive-rename_files">rename_files</a>, <a href="#abs_archive-repo_mapping">repo_mapping</a>, <a href="#abs_archive-sha256">sha256</a>, <a href="#abs_archive-strip_prefix">strip_prefix</a>, <a href="#abs_archive-type">type</a>, <a href="#abs_archive-url">url</a>)
</pre>

Downloads a Bazel repository as a compressed archive file from an Azure Blob Storage account, decompresses it,
and makes its targets available for binding.

It supports the following file extensions: `"zip"`, `"jar"`, `"war"`, `"aar"`, `"tar"`,
`"tar.gz"`, `"tgz"`, `"tar.xz"`, `"txz"`, `"tar.zst"`, `"tzst"`, `tar.bz2`, `"ar"`,
or `"deb"`.

Examples:
  Suppose your code depends on a private library packaged as a `.tar.gz`
  which is available from https://myorg.blob.core.windows.net/libmagic.tar.gz. This `.tar.gz` file
  contains the following directory structure:

  ```
 MODULE.bazel
  src/
    magic.cc
    magic.h
  ```

  In the local repository, the user creates a `magic.BUILD` file which
  contains the following target definition:

  ```starlark
  cc_library(
      name = "lib",
      srcs = ["src/magic.cc"],
      hdrs = ["src/magic.h"],
  )
  ```

  Targets in the main repository can depend on this target if the
  following lines are added to `MODULE.bazel`:

  ```starlark
  abs_archive = use_repo_rule("@rulesabs//abs:repo_rules.bzl", "abs_archive")

  abs_archive(
      name = "magic",
      url = "https://myorg.blob.core.windows.net/libmagic.tar.gz",
      sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      build_file = "@//:magic.BUILD",
  )
  ```

  Then targets would specify `@magic//:lib` as a dependency.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="abs_archive-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="abs_archive-build_file"></a>build_file |  The file to use as the BUILD file for this repository.This attribute is an absolute label (use '@//' for the main repo). The file does not need to be named BUILD, but can be (something like BUILD.new-repo-name may work well for distinguishing it from the repository's actual BUILD files. Either build_file or build_file_content can be specified, but not both.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="abs_archive-build_file_content"></a>build_file_content |  The content for the BUILD file for this repository. Either build_file or build_file_content can be specified, but not both.   | String | optional |  `""`  |
| <a id="abs_archive-canonical_id"></a>canonical_id |  A canonical ID of the file downloaded.<br><br>If specified and non-empty, Bazel will not take the file from cache, unless it was added to the cache by a request with the same canonical ID.<br><br>If unspecified or empty, Bazel by default uses the URLs of the file as the canonical ID. This helps catch the common mistake of updating the URLs without also updating the hash, resulting in builds that succeed locally but fail on machines without the file in the cache.   | String | optional |  `""`  |
| <a id="abs_archive-integrity"></a>integrity |  Expected checksum in Subresource Integrity format of the file downloaded.<br><br>This must match the checksum of the file downloaded. It is a security risk to omit the checksum as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but either this attribute or `sha256` should be set before shipping.   | String | optional |  `""`  |
| <a id="abs_archive-patch_strip"></a>patch_strip |  Strip the specified number of leading components from file names.   | Integer | optional |  `0`  |
| <a id="abs_archive-patches"></a>patches |  A list of files that are to be applied as patches after extracting the archive. It uses the Bazel-native patch implementation which doesn't support fuzz match and binary patch.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="abs_archive-rename_files"></a>rename_files |  An optional dict specifying files to rename during the extraction. Archive entries with names exactly matching a key will be renamed to the value, prior to any directory prefix adjustment. This can be used to extract archives that contain non-Unicode filenames, or which have files that would extract to the same path on case-insensitive filesystems.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="abs_archive-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |
| <a id="abs_archive-sha256"></a>sha256 |  The expected SHA-256 of the file downloaded.<br><br>This must match the SHA-256 of the file downloaded. It is a security risk to omit the SHA-256 as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but either this attribute or `integrity` should be set before shipping.   | String | optional |  `""`  |
| <a id="abs_archive-strip_prefix"></a>strip_prefix |  A directory prefix to strip from the extracted files.<br><br>Many archives contain a top-level directory that contains all of the useful files in archive. Instead of needing to specify this prefix over and over in the `build_file`, this field can be used to strip it from all of the extracted files.<br><br>For example, suppose you are using `foo-lib-latest.zip`, which contains the directory `foo-lib-1.2.3/` under which there is a `WORKSPACE` file and are `src/`, `lib/`, and `test/` directories that contain the actual code you wish to build. Specify `strip_prefix = "foo-lib-1.2.3"` to use the `foo-lib-1.2.3` directory as your top-level directory.<br><br>Note that if there are files outside of this directory, they will be discarded and inaccessible (e.g., a top-level license file). This includes files/directories that start with the prefix but are not in the directory (e.g., `foo-lib-1.2.3.release-notes`). If the specified prefix does not match a directory in the archive, Bazel will return an error.   | String | optional |  `""`  |
| <a id="abs_archive-type"></a>type |  The archive type of the downloaded file.<br><br>By default, the archive type is determined from the file extension of the URL. If the file has no extension, you can explicitly specify one of the following: `"zip"`, `"jar"`, `"war"`, `"aar"`, `"tar"`, `"tar.gz"`, `"tgz"`, `"tar.xz"`, `"txz"`, `"tar.zst"`, `"tzst"`, `"tar.bz2"`, `"ar"`, or `"deb"`.   | String | optional |  `""`  |
| <a id="abs_archive-url"></a>url |  A URL to a file that will be made available to Bazel. This must be a 'http[s]://' URL.   | String | required |  |


<a id="abs_file"></a>

## abs_file

<pre>
load("@rules_abs//abs:repo_rules.bzl", "abs_file")

abs_file(<a href="#abs_file-name">name</a>, <a href="#abs_file-canonical_id">canonical_id</a>, <a href="#abs_file-downloaded_file_path">downloaded_file_path</a>, <a href="#abs_file-executable">executable</a>, <a href="#abs_file-integrity">integrity</a>, <a href="#abs_file-repo_mapping">repo_mapping</a>, <a href="#abs_file-sha256">sha256</a>, <a href="#abs_file-url">url</a>)
</pre>

Downloads a file from an Azure Blob Storage bucket and makes it available to be used as a file group.

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

  Targets would specify `@azure_cli//file` as a dependency to depend on this file.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="abs_file-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="abs_file-canonical_id"></a>canonical_id |  A canonical ID of the file downloaded.<br><br>If specified and non-empty, Bazel will not take the file from cache, unless it was added to the cache by a request with the same canonical ID.<br><br>If unspecified or empty, Bazel by default uses the URLs of the file as the canonical ID. This helps catch the common mistake of updating the URLs without also updating the hash, resulting in builds that succeed locally but fail on machines without the file in the cache.   | String | optional |  `""`  |
| <a id="abs_file-downloaded_file_path"></a>downloaded_file_path |  Optional output path for the downloaded file. The remote path from the URL is used as a fallback.   | String | optional |  `""`  |
| <a id="abs_file-executable"></a>executable |  If the downloaded file should be made executable.   | Boolean | optional |  `False`  |
| <a id="abs_file-integrity"></a>integrity |  Expected checksum in Subresource Integrity format of the file downloaded.<br><br>This must match the checksum of the file downloaded. It is a security risk to omit the checksum as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but either this attribute or `sha256` should be set before shipping.   | String | optional |  `""`  |
| <a id="abs_file-repo_mapping"></a>repo_mapping |  In `WORKSPACE` context only: a dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.<br><br>For example, an entry `"@foo": "@bar"` declares that, for any time this repository depends on `@foo` (such as a dependency on `@foo//some:target`, it should actually resolve that dependency within globally-declared `@bar` (`@bar//some:target`).<br><br>This attribute is _not_ supported in `MODULE.bazel` context (when invoking a repository rule inside a module extension's implementation function).   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  |
| <a id="abs_file-sha256"></a>sha256 |  The expected SHA-256 of the file downloaded.<br><br>This must match the SHA-256 of the file downloaded. _It is a security risk to omit the SHA-256 as remote files can change._ At best omitting this field will make your build non-hermetic. It is optional to make development easier but should be set before shipping.   | String | optional |  `""`  |
| <a id="abs_file-url"></a>url |  A URL to a file that will be made available to Bazel. This must be a 'https://' URL.   | String | required |  |

<a id="abs_container"></a>

## abs_container

<pre>
abs_container = use_extension("@rules_abs//abs:extensions.bzl", "abs_container")
abs_container.from_file(<a href="#abs_container.from_file-name">name</a>, <a href="#abs_container.from_file-container">container</a>, <a href="#abs_container.from_file-dev_dependency">dev_dependency</a>, <a href="#abs_container.from_file-lockfile">lockfile</a>, <a href="#abs_container.from_file-lockfile_jsonpath">lockfile_jsonpath</a>, <a href="#abs_container.from_file-method">method</a>,
                        <a href="#abs_container.from_file-storage_account">storage_account</a>)
</pre>

Downloads a collection of objects from an Azure Storage container and makes them available under a single hub repository name.

Examples:
  Suppose your code depends on a collection of large assets that are used during code generation or testing. Those assets are stored in a private Azure Storage container.

  In the local repository, the user creates a `abs_lock.json` JSON lockfile describing the required objects, including their expected hashes:

  ```json
    {
        "trainingdata/model/small.bin": {
            "sha256": "abd83816bd236b266c3643e6c852b446f068fe260f3296af1a25b550854ec7e5"
        },
        "trainingdata/model/medium.bin": {
            "sha256": "c6f9568f930b16101089f1036677bb15a3185e9ed9b8dbce2f518fb5a52b6787"
        },
        "trainingdata/model/large.bin": {
            "sha256": "b3ccb0ba6f7972074b0a1e13340307abfd5a5eef540c521a88b368891ec5cd6b"
        },
        "trainingdata/model/very_large.bin": {
            "remote_path": "weird/nested/path/extra/model/very_large.bin",
            "integrity": "sha256-Oibw8PV3cDY84HKv3sAWIEuk+R2s8Hwhvlg6qg4H7uY="
        }
    }
  ```

  The exact format for the lockfile is a JSON object where each key is a path to a local file in the repository and the value is a JSON object with the following keys:

  - `sha256`: the expected sha256 hash of the file. Required unless `integrity` is used.
  - `integrity`: the expected SRI value of the file. Required unless `sha256` is used.
  - `remote_path`: name of the object within the bucket. If not set, the local path is used.

  Targets in the main repository can depend on this target if the
  following lines are added to `MODULE.bazel`:

  ```starlark
  abs_container = use_extension("@rules_abs//abs:extensions.bzl", "abs_container")
  abs_container.from_file(
      name = "trainingdata",
      container = "stuff",
      storage_account = "my_org_assets",
      lockfile = "@//:abs_lock.json",
  )
  ```

  Then targets would specify labels like `@trainingdata//:stuff/trainingdata/model/very_large.bin` as a dependency.


**TAG CLASSES**

<a id="abs_container.from_file"></a>

### from_file

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="abs_container.from_file-name"></a>name |  Name of the hub repository containing referencing all blobs   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="abs_container.from_file-container"></a>container |  Name of the container in the storage account   | String | required |  |
| <a id="abs_container.from_file-dev_dependency"></a>dev_dependency |  If true, this dependency will be ignored if the current module is not the root module or `--ignore_dev_dependency` is enabled.   | Boolean | optional |  `False`  |
| <a id="abs_container.from_file-lockfile"></a>lockfile |  JSON lockfile containing objects to load from the Azure Storage Account container   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="abs_container.from_file-lockfile_jsonpath"></a>lockfile_jsonpath |  JSONPath expression referencing the dict of paths. By default, the top-level object is used.   | String | optional |  `""`  |
| <a id="abs_container.from_file-method"></a>method |  Method used for downloading:<br><br>`symlink`: lazy fetching with symlinks, `alias`: lazy fetching with alias targets, `copy`: lazy fetching with full file copies, `eager`: all objects are fetched eagerly   | String | optional |  `"symlink"`  |
| <a id="abs_container.from_file-storage_account"></a>storage_account |  Name of the Azure Storage Account   | String | required |  |

## Troubleshooting

- Credential helper not found

    ```
    WARNING: Error retrieving auth headers, continuing without: Failed to get credentials for 'https://malte-s3-bazel-test.s3.amazonaws.com/hello_world' from helper 'tools/credential-helper': Cannot run program "tools/credential-helper" (in directory "..."): error=2, No such file or directory
    ```

    You need to install a credential helper (either [`tweag-credential-helper`][tweag-credential-helper], or your own) as explained [above](#installation).

- HTTP 401 or 403 error codes

    ```
    ERROR: Target parsing failed due to unexpected exception: java.io.IOException: Error downloading [https://s3.amazonaws.com/...] to ...: GET returned 403 Forbidden
    ```

    Follow the setup instructions of your credential helper ([`tweag-credential-helper` docs][tweag-credential-helper-s3-docs]).

-  Checksum mismatch (empty file downloaded)

    ```
    Error in wait: com.google.devtools.build.lib.bazel.repository.downloader.UnrecoverableHttpException: Checksum was e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 but wanted <actual>
    ```

    Check if you are using `--experimental_remote_downloader`. If you do, the remote cache may drop your auth header and silently give you empty files instead. One workaround is setting `--experimental_remote_downloader_local_fallback` in `.bazelrc`.

## Acknowledgements

_`rules_abs` is based on [`rules_s3`][rules_s3_github], which was initially developed by [IMAX][imax] and now maintained by Tweag. This repo is privately maintained by myself_

[example]: /examples/full/
[example_cred_helper]: /examples/full/tools/mock-credential-helper
[abs]: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction
[rules_s3_github]: https://github.com/tweag/rules_s3
[bcr]: https://registry.bazel.build/modules/rules_abs
[imax]: https://www.imax.com/en/us/sct
[tweag-credential-helper]: https://github.com/tweag/credential-helper
