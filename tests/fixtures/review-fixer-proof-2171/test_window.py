import unittest
from window import last_n

class WindowTest(unittest.TestCase):
    def test_zero(self):
        self.assertEqual(last_n([1, 2, 3], 0), [])
    def test_two(self):
        self.assertEqual(last_n([1, 2, 3], 2), [2, 3])

if __name__ == "__main__":
    unittest.main()
