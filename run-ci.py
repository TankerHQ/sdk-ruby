from typing import Any
import argparse
import os
import sys

from path import Path

import tankerci
import tankerci.bump
import tankerci.conan
import tankerci.git

DEPLOYED_TANKER = "tanker/2.5.1-alpha1@tanker/stable"
LOCAL_TANKER = "tanker/dev@tanker/dev"


class Builder:
    def __init__(self, *, src_path: Path, tanker_conan_ref: str):
        self.src_path = src_path
        self.tanker_conan_ref = tanker_conan_ref
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


def create_builder(args: Any) -> Builder:
    src_path = Path.getcwd()

    if args.use_tanker == "deployed":
        tanker_conan_ref = DEPLOYED_TANKER
    elif args.use_tanker == "local":
        tanker_conan_ref = LOCAL_TANKER
        tankerci.conan.export(
            src_path=Path.getcwd().parent / "sdk-native", ref_or_channel="tanker/dev"
        )
    elif args.use_tanker == "same-as-branch":
        tanker_conan_ref = LOCAL_TANKER
        workspace = tankerci.git.prepare_sources(repos=["sdk-native", "sdk-ruby"])
        src_path = workspace / "sdk-ruby"
        tankerci.conan.export(
            src_path=workspace / "sdk-native", ref_or_channel="tanker/dev"
        )
    else:
        raise RuntimeError("invalid argument")

    builder = Builder(src_path=src_path, tanker_conan_ref=tanker_conan_ref)
    return builder


def build_and_test(args: Any) -> None:
    builder = create_builder(args)
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
        "--use-tanker", choices=["deployed", "local", "same-as-branch"], default="local"
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
