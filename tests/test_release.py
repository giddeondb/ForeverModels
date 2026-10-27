from pathlib import Path
import sys
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import release
from package import build, FILES


class ReleaseTests(unittest.TestCase):
    def test_minor_versions_follow_highest_tag(self):
        self.assertEqual(release.next_version([]), 'v0.7.0')
        self.assertEqual(release.next_version(['v0.7.0', 'v0.12.4', 'v0.13.0-beta']), 'v0.13.0')
        self.assertEqual(release.next_version(['v1.2.9']), 'v1.3.0')

    def test_backlog_skips_published_and_resumes_draft(self):
        sources = {'a': 'v0.7.0', 'b': 'v0.8.0'}
        releases = {'v0.7.0': {'draft': False}, 'v0.8.0': {'draft': True}}
        self.assertEqual(release.pending(['a', 'b', 'c', 'd'], sources, releases),
                         [('b', 'v0.8.0'), ('c', None), ('d', None)])

    def test_reserved_tag_without_draft_is_reused(self):
        self.assertEqual(release.pending(['a'], {'a': 'v0.7.0'}, {}), [('a', 'v0.7.0')])

    def test_draft_retry_does_not_create_release(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(release, 'run', return_value='Change') as run:
            root = Path(temp)
            (root / 'dist').mkdir()
            release.publish('a' * 40, 'v0.7.0', {'draft': True}, root, [root / 'asset.zip'])
            commands = [c.args for c in run.call_args_list]
            self.assertFalse(any(c[:3] == ('gh', 'release', 'create') for c in commands))
            self.assertEqual(commands[-1][:3], ('gh', 'release', 'edit'))
            self.assertIn('--draft=false', commands[-1])

    def test_published_release_cannot_be_overwritten(self):
        with patch.object(release, 'run') as run:
            with self.assertRaises(RuntimeError):
                release.publish('a' * 40, 'v0.7.0', {'draft': False}, ROOT, [])
            run.assert_not_called()

    def test_failed_upload_leaves_draft_unpublished(self):
        def fake(*args, **kwargs):
            if args[:3] == ('gh', 'release', 'upload'):
                raise RuntimeError('Upload failed')
            return 'Change'
        with tempfile.TemporaryDirectory() as temp, patch.object(release, 'run', side_effect=fake) as run:
            root = Path(temp)
            (root / 'dist').mkdir()
            with self.assertRaises(RuntimeError):
                release.publish('a' * 40, 'v0.7.0', None, root, [])
            self.assertFalse(any(c.args[:3] == ('gh', 'release', 'edit') for c in run.call_args_list))

    def test_package_is_reproducible_and_excludes_private_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in FILES:
                (root / name).write_bytes((ROOT / name).read_bytes())
            (root / '.env').write_text('DO_NOT_PACKAGE=private')
            first, alias = build(root)
            original = first.read_bytes()
            self.assertEqual(original, alias.read_bytes())
            self.assertEqual(original, build(root)[0].read_bytes())
            with zipfile.ZipFile(first) as archive:
                self.assertEqual(set(archive.namelist()), {f'ForeverModels/{f}' for f in FILES})
                for name in FILES:
                    self.assertEqual(archive.read(f'ForeverModels/{name}'), (root / name).read_bytes())

    def test_real_git_backlog_resumes_after_reserved_tag(self):
        self._check_real_git_backlog()

    def test_real_git_marked_reserved_tags_and_drafts_resume(self):
        for marker in ('[skip ci]', '[ci skip]'):
            for draft in (False, True):
                with self.subTest(marker=marker, draft=draft):
                    self._check_real_git_backlog(marker, draft)

    def _check_real_git_backlog(self, marker='', draft=False):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'repo'
            bare = Path(temp) / 'remote.git'
            root.mkdir()
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root,
                                               stderr=subprocess.DEVNULL, text=True).strip()
            git('init', '-b', 'main')
            git('config', 'user.name', 'Test')
            git('config', 'user.email', 'test@example.invalid')
            (root / 'baseline').write_text('baseline')
            git('add', '.')
            git('commit', '-m', 'Baseline')
            base = git('rev-parse', 'HEAD')
            for name in (*FILES, 'tests/test.lua'):
                dest = root / name
                dest.parent.mkdir(exist_ok=True)
                dest.write_bytes((ROOT / name).read_bytes())
            git('add', '.')
            git('commit', '-m', f'First addon commit {marker}'.strip())
            first = git('rev-parse', 'HEAD')
            for skip in ('[skip ci]', '[ci skip]'):
                for message in (f'Docs {skip} update', f'Docs update\n\nDetails {skip} here.'):
                    with (root / 'README.md').open('a') as stream:
                        stream.write(f'\n{message}\n')
                    git('commit', '-am', message)
            with (root / 'README.md').open('a') as stream:
                stream.write('\nDocumentation change.\n')
            git('commit', '-am', 'Second main commit')
            second = git('rev-parse', 'HEAD')
            git('init', '--bare', str(bare))
            git('remote', 'add', 'origin', str(bare))
            git('push', '-u', 'origin', 'main')
            real_run = release.run
            def local_run(*args, cwd=None, env=None):
                return real_run(*args, cwd=cwd or root, env=env)
            catalog = {}
            attempts = []
            def fake_publish(source, tag, existing, work, paths):
                attempts.append((source, tag))
                if len(attempts) == 1:
                    if draft:
                        catalog[tag] = {'draft': True}
                    raise RuntimeError('Interrupted after tag push')
                self.assertEqual(existing, {'draft': True} if draft and source == first else None)
                self.assertEqual(paths[0].read_bytes(), paths[1].read_bytes())
                catalog[tag] = {'draft': False}
            with patch.object(release, 'BASE', base), \
                 patch.object(release, 'run', side_effect=local_run), \
                 patch.object(release, 'release_catalog', side_effect=lambda: catalog.copy()), \
                 patch.object(release, 'publish', side_effect=fake_publish), \
                 patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}):
                # Simulate a reservation made before skip markers were honored.
                with patch.object(release, 'SKIP_CI', ()), \
                     self.assertRaisesRegex(RuntimeError, 'Interrupted'):
                    release.main()
                self.assertEqual(git('tag', '--list'), 'v0.7.0')
                reserved_sha = git('rev-parse', 'v0.7.0')
                expected = [(first, 'v0.7.0'), (first, 'v0.7.0'), (second, 'v0.8.0')]
                for _ in range(3):
                    release.main()
                    self.assertEqual(attempts, expected)
                    self.assertEqual(sorted(git('tag', '--list').splitlines()), ['v0.7.0', 'v0.8.0'])
                    self.assertEqual(git('rev-parse', 'v0.7.0'), reserved_sha)
                    self.assertEqual(git('ls-remote', '--tags', 'origin').splitlines(), [
                        f'{reserved_sha}\trefs/tags/v0.7.0',
                        f'{git("rev-parse", "v0.8.0")}\trefs/tags/v0.8.0',
                    ])
            self.assertEqual(git('rev-parse', 'main'), second)
            self.assertEqual(git('rev-parse', 'v0.7.0^'), first)
            self.assertEqual(git('rev-parse', 'v0.8.0^'), second)
            self.assertIn('## Version: 0.8.0', git('show', 'v0.8.0:ForeverModels.toc'))

    def test_package_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'ForeverModels.toc').write_text('## Version: 0.7.0\n')
            (root / 'ForeverModels.lua').symlink_to(ROOT / 'ForeverModels.lua')
            with self.assertRaises(RuntimeError):
                build(root)


if __name__ == '__main__':
    unittest.main()
