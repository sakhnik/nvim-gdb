#!/usr/bin/env python

import unittest
import engine
from backends import Backends


backs = Backends().get()
eng = engine.Engine()


class TestGeneric(unittest.TestCase):

    def tearDown(self):
        eng.exe("GdbDebugStop")
        self.assertEqual(1, eng.eval("tabpagenr('$')"))
        self.assertEqual({}, eng.getSigns())

    def smoke(self, back):
        spec = backs[back]
        eng.feed(spec['launch'], 1000)
        eng.feed(spec['tbreak_main'])
        eng.feed('run\n', 1000)
        eng.feed('<esc>')

        self.assertEqual({'cur': 'test.cpp:17'}, eng.getSigns())

        eng.feed('<f10>')
        self.assertEqual({'cur': 'test.cpp:19'}, eng.getSigns())

        eng.feed('<f11>')
        self.assertEqual({'cur': 'test.cpp:10'}, eng.getSigns())

        eng.feed('<c-p>')
        self.assertEqual({'cur': 'test.cpp:19'}, eng.getSigns())

        eng.feed('<c-n>')
        self.assertEqual({'cur': 'test.cpp:10'}, eng.getSigns())

        eng.feed('<f12>')
        signs = eng.getSigns()
        self.assertEqual(1, len(signs))
        # different for different compilers
        self.assertIn(signs["cur"], {'test.cpp:17', 'test.cpp:19'})

        eng.feed('<f5>')
        self.assertEqual({}, eng.getSigns())

    @unittest.skipUnless('gdb' in backs.keys(), 'Only for GDB')
    def test_smoke_gdb(self):
        self.smoke('gdb')

    @unittest.skipUnless('lldb' in backs.keys(), 'Only for LLDB')
    def test_smoke_lldb(self):
        self.smoke('lldb')

    def breaks(self, back):
        # Test toggling breakpoints.
        spec = backs[back]
        # TODO: Investigate socket connection race when the delay is small
        # here, like 1ms
        eng.feed(spec['launch'], 1000)
        eng.feed('<esc><c-w>k')
        eng.feed(":e src/test.cpp\n")
        eng.feed(':5<cr>')
        eng.feed('<f8>', 100)
        self.assertEqual({'break': {1: [5]}}, eng.getSigns())

        eng.exe("GdbRun", 1000)
        self.assertEqual({'cur': 'test.cpp:5', 'break': {1: [5]}}, eng.getSigns())

        eng.feed('<f8>')
        self.assertEqual({'cur': 'test.cpp:5'}, eng.getSigns())

    @unittest.skipUnless('gdb' in backs.keys(), 'Only for GDB')
    def test_breaks_gdb(self):
        self.breaks('gdb')

    @unittest.skipUnless('lldb' in backs.keys(), 'Only for LLDB')
    def test_breaks_lldb(self):
        self.breaks('lldb')

#    it "multiview", ->
#        -- Test multiple views.
#        names = [k for k,_ in pairs(backends)]
#        backend1 = names[1]
#        backend2 = #names > 1 and names[2] or backend1
#
#        -- Launch the first backend
#        eng\feed backends[backend1].launch, 1000
#        eng\feed backends[backend1].tbreak_main
#        eng\feed 'run\n', 1000
#        eng\feed '<esc>'
#        eng\feed '<c-w>w'
#        eng\feed ':11<cr>'
#        eng\feed '<f8>'
#        eng\feed '<f10>'
#        eng\feed '<f11>'
#
#        assert.are.same {'cur': 'test.cpp:10', 'break': {[1]: {11}}}, eng\getSigns!
#
#        -- Then launch the second backend
#        eng\feed backends[backend2].launch, 1000
#        eng\feed backends[backend2].tbreak_main
#        eng\feed 'run\n', 1000
#        eng\feed '<esc>'
#        eng\feed '<c-w>w'
#        eng\feed ':5<cr>'
#        eng\feed '<f8>'
#        eng\feed ':12<cr>'
#        eng\feed '<f8>'
#        eng\feed '<f10>'
#
#        assert.are.same {'cur': 'test.cpp:19', 'break': {[1]: {5, 12}}}, eng\getSigns!
#
#        -- Switch to the first backend
#        eng\feed '2gt'
#        assert.are.same {'cur': 'test.cpp:10', 'break': {[1]: {11}}}, eng\getSigns!
#
#        -- Quit
#        eng\feed 'ZZ'
#
#        -- Switch back to the second backend
#        assert.are.same {'cur': 'test.cpp:19', 'break': {[1]: {5, 12}}}, eng\getSigns!
#
#        -- The last debugger is quit in the after_each
#
#    describe "interrupt", ->
#        -- Test interrupt.
#        for backend, spec in pairs(backends)
#            it '#'..backend, ->
#                eng\feed spec.launch, 1000
#                eng\feed 'run 4294967295\n', 1000
#                eng\feed '<esc>'
#                eng\feed ':GdbInterrupt\n', 300
#
#                assert.are.same {'cur': 'test.cpp:22'}, eng\getSigns!
#
#    describe "until", ->
#        for backend, spec in pairs(backends)
#            it '#'..backend, ->
#                eng\feed spec.launch, 1000
#                eng\feed spec.tbreak_main
#                eng\feed 'run\n', 1000
#                eng\feed '<esc>'
#
#                eng\feed '<c-w>w'
#                eng\feed ':21<cr>'
#                eng\feed '<f4>'
#
#                assert.are.same {'cur': 'test.cpp:21'}, eng\getSigns!
#
#    describe 'program exit', ->
#        -- Test the cursor is hidden after program end.
#        for backend, spec in pairs(backends)
#            it '#'..backend, ->
#                eng\feed spec.launch, 1000
#                eng\feed spec.tbreak_main
#                eng\feed 'run\n', 1000
#                eng\feed '<esc>'
#
#                eng\feed '<f5>'
#                assert.are.same {}, eng\getSigns!
#
#    describe '#eval', ->
#        -- Test eval <cword>.
#        for backend, spec in pairs(backends)
#            it '#'..backend, ->
#                eng\feed spec.launch, 1000
#                eng\feed spec.tbreak_main
#                eng\feed 'run\n', 1000
#                eng\feed '<esc>'
#                eng\feed '<c-w>w'
#                eng\feed '<f10>'
#
#                eng\feed '^<f9>'
#                assert.are.same 'print Foo', eng\eval 'GdbTestPeek("lastCommand")'
#
#                eng\feed '/Lib::Baz\n'
#                eng\feed 'vt('
#                eng\feed ':GdbEvalRange\n'
#                assert.are.equal 'print Lib::Baz', eng\eval 'GdbTestPeek("lastCommand")'


if __name__ == "__main__":
    unittest.main()
