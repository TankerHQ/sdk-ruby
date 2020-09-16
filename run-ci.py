from typing import Any, List
import argparse
import os
import sys
from enum import Enum

from path import Path

import tankerci
import tankerci.bump
import tankerci.conan
import tankerci.git
import tankerci.gitlab

LOCAL_TANKER = "tanker/dev@"


def retrieve_conan_reference(*, recipe_dir: Path) -> str:
    recipe_info = tankerci.conan.inspect(recipe_dir)
    name = recipe_info["name"]
    version = recipe_info["version"]
    return f"{name}/{version}@"


class TankerSource(Enum):
    LOCAL = "local"
    SAME_AS_BRANCH = "same-as-branch"
    DEPLOYED = "deployed"
    UPSTREAM = "upstream"


class Builder:
    def __init__(
        self,
        *,
        src_path: Path,
        tanker_conan_ref: str,
        tanker_conan_extra_flags: List[str],
    ):
        self.src_path = src_path
        self.tanker_conan_ref = tanker_conan_ref
        self.tanker_conan_extra_flags = tanker_conan_extra_flags
        if sys.platform.startswith("linux"):
            self.arch = "linux64"
        else:
            self.arch = "mac64"

    def get_build_path(self) -> Path:
        build_path = self.src_path / "vendor/libctanker" / self.arch
        build_path.makedirs_p()
        return build_path

    def install_sdk_native(self, *, profile: str) -> None:
        install_path = self.get_build_path()
        # fmt: off
        tankerci.conan.run(
            "install", self.tanker_conan_ref,
            "--update",
            *self.tanker_conan_extra_flags,
            "--profile", profile,
            "--install-folder", install_path,
            "--generator", "deploy"
        )
        # fmt: on

    def install_ruby_deps(self):
        with self.src_path:
            tankerci.run("bundle", "install")

    def test(self) -> None:
        with self.src_path:
            tankerci.run("bundle", "exec", "rake", "spec")


def create_builder(tanker_source: TankerSource, *, profile: str) -> Builder:
    src_path = Path.getcwd()
    tanker_conan_ref = LOCAL_TANKER
    tanker_conan_extra_flags = []

    if tanker_source == TankerSource.DEPLOYED:
        tanker_conan_ref = os.environ["SDK_NATIVE_LATEST_CONAN_REFERENCE"]
    elif tanker_source == TankerSource.UPSTREAM:
        artifacts_folder = Path.getcwd() / "package"
        package_folder = artifacts_folder / profile

        tanker_conan_ref = retrieve_conan_reference(recipe_dir=artifacts_folder)

        tankerci.conan.export_pkg(
            Path.getcwd() / "package" / "conanfile.py",
            profile=profile,
            force=True,
            package_folder=package_folder,
        )
    elif tanker_source == TankerSource.LOCAL:
        tankerci.conan.export(
            src_path=Path.getcwd().parent / "sdk-native", ref_or_channel=LOCAL_TANKER
        )
        tanker_conan_extra_flags.append("--build=tanker")
    elif tanker_source == TankerSource.SAME_AS_BRANCH:
        workspace = tankerci.git.prepare_sources(repos=["sdk-native", "sdk-ruby"])
        src_path = workspace / "sdk-ruby"
        tankerci.conan.export(
            src_path=workspace / "sdk-native", ref_or_channel=LOCAL_TANKER
        )
        tanker_conan_extra_flags.append("--build=tanker")

    builder = Builder(
        src_path=src_path,
        tanker_conan_ref=tanker_conan_ref,
        tanker_conan_extra_flags=tanker_conan_extra_flags,
    )
    return builder


def build_and_test(args: Any) -> None:
    builder = create_builder(args.tanker_source, profile=args.profile)
    builder.install_ruby_deps()
    builder.install_sdk_native(profile=args.profile)
    builder.test()


def lint() -> None:
    tankerci.run("bundle", "install")
    tankerci.run("bundle", "exec", "rake", "rubocop")


def deploy(version: str) -> None:
    expected_libs = [
        "vendor/libctanker/linux64/tanker/lib/libctanker.so",
        "vendor/libctanker/mac64/tanker/lib/libctanker.dylib",
    ]
    for lib in expected_libs:
        expected_path = Path(lib)
        if not expected_path.exists():
            sys.exit(f"Error: {expected_path} does not exist!")

    tankerci.bump.bump_files(version)

    # Note: this commands also re-gerenates the lock as a side-effect since the
    # gemspec has changed - keep this before the git commands
    tankerci.run("bundle", "install")

    # Note: `bundle exec rake build` does not like dirty git repos, so make a
    # commit with the new changes first
    tankerci.git.run(Path.getcwd(), "add", "--update", ".")
    tankerci.git.run(Path.getcwd(), "commit", "--message", f"Bump to {version}")
    tankerci.run("bundle", "exec", "rake", "build")
    tankerci.run("bundle", "exec", "rake", "push")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--isolate-conan-user-home",
        action="store_true",
        dest="home_isolation",
        default=False,
    )

    subparsers = parser.add_subparsers(title="subcommands", dest="command")

    build_and_test_parser = subparsers.add_parser("build-and-test")
    build_and_test_parser.add_argument(
        "--use-tanker",
        type=TankerSource,
        default=TankerSource.LOCAL,
        dest="tanker_source",
    )
    build_and_test_parser.add_argument("--profile", default="default")

    reset_branch_parser = subparsers.add_parser("reset-branch")
    reset_branch_parser.add_argument("branch")

    download_artifacts_parser = subparsers.add_parser("download-artifacts")
    download_artifacts_parser.add_argument("--project-id", required=True)
    download_artifacts_parser.add_argument("--pipeline-id", required=True)
    download_artifacts_parser.add_argument("--job-name", required=True)

    deploy_parser = subparsers.add_parser("deploy")
    deploy_parser.add_argument("--version", required=True)
    subparsers.add_parser("lint")
    subparsers.add_parser("mirror")

    args = parser.parse_args()

    if args.home_isolation:
        tankerci.conan.set_home_isolation()
        tankerci.conan.update_config()

    command = args.command
    if command == "build-and-test":
        build_and_test(args)
    elif command == "deploy":
        deploy(args.version)
    elif command == "lint":
        lint()
    elif command == "reset-branch":
        fallback = os.environ["CI_COMMIT_REF_NAME"]
        ref = tankerci.git.find_ref(
            Path.getcwd(), [f"origin/{args.branch}", f"origin/{fallback}"]
        )
        tankerci.git.reset(Path.getcwd(), ref)
    elif command == "download-artifacts":
        tankerci.gitlab.download_artifacts(
            project_id=args.project_id,
            pipeline_id=args.pipeline_id,
            job_name=args.job_name,
        )
    elif args.command == "mirror":
        tankerci.git.mirror(github_url="git@github.com:TankerHQ/sdk-ruby")
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
