<?php

namespace App\DataFixtures;

use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Common\Persistence\ObjectManager;
use App\Entity\Post;

class AppFixtures extends Fixture
{
    public function load(ObjectManager $manager)
    {
        for ($i = 0; $i < 10; $i++) {
            $post = new Post();
            $post->setName('Post '  . $i);
            $post->setContent(str_repeat('Content ', rand(5, 20)));
            $manager->persist($post);
        }

        $manager->flush();
    }
}
