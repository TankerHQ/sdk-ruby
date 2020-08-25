from typing import Any
import argparse
import os
import sys
from enum import Enum

from path import Path

import tankerci
import tankerci.bump
import tankerci.conan
import tankerci.git

DEPLOYED_TANKER = "tanker/2.5.0@tanker/stable"
LOCAL_TANKER = "tanker/dev@tanker/dev"


class TankerSource(Enum):
    LOCAL = "local"
    SAME_AS_BRANCH = "same-as-branch"
    DEPLOYED = "deployed"


class Builder:
    def __init__(self, *, src_path: Path, tanker_source: TankerSource):
        self.src_path = src_path
        if tanker_source in [TankerSource.LOCAL, TankerSource.SAME_AS_BRANCH]:
            self.tanker_conan_ref = LOCAL_TANKER
            self.tanker_conan_extra_flags = ["--update", "--build=tanker"]
        else:
            self.tanker_conan_ref = DEPLOYED_TANKER
            self.tanker_conan_extra_flags = []
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


def create_builder(tanker_source: TankerSource) -> Builder:
    src_path = Path.getcwd()

    if tanker_source == TankerSource.LOCAL:
        tankerci.conan.export(
            src_path=Path.getcwd().parent / "sdk-native", ref_or_channel="tanker/dev"
        )
    elif tanker_source == TankerSource.SAME_AS_BRANCH:
        workspace = tankerci.git.prepare_sources(repos=["sdk-native", "sdk-ruby"])
        src_path = workspace / "sdk-ruby"
        tankerci.conan.export(
            src_path=workspace / "sdk-native", ref_or_channel="tanker/dev"
        )

    builder = Builder(src_path=src_path, tanker_source=tanker_source)
    return builder


def build_and_test(args: Any) -> None:
    builder = create_builder(args.tanker_source)
    builder.install_ruby_deps()
    builder.install_sdk_native(profile=args.profile)
    builder.test()


def lint() -> None:
    tankerci.run("bundle", "install")
    tankerci.run("bundle", "exec", "rake", "rubocop")


def deploy() -> None:
    expected_libs = [
        "vendor/libctanker/linux64/tanker/lib/libctanker.so",
        "vendor/libctanker/mac64/tanker/lib/libctanker.dylib",
    ]
    for lib in expected_libs:
        expected_path = Path(lib)
        if not expected_path.exists():
            sys.exit(f"Error: {expected_path} does not exist!")

    tag = os.environ["CI_COMMIT_TAG"]
    version = tankerci.bump.version_from_git_tag(tag)
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

    subparsers.add_parser("deploy")
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
        deploy()
    elif command == "lint":
        lint()
    elif args.command == "mirror":
        tankerci.git.mirror(github_url="git@github.com:TankerHQ/sdk-ruby")
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
